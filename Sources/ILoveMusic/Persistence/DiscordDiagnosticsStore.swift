import Foundation
import os

/// Rolling diagnostic log for Discord Rich Presence IPC events.
///
/// Contract:
///   - File: `<Application Support>/ILoveMusic/discord-log.json`.
///   - JSON array of `ControlLogEntry`, ISO-8601 timestamps.
///   - Atomic writes (`Data.write(options: .atomic)`).
///   - Capped at `maxEntries` (default 120); oldest entries fall off first.
///
/// Behavior:
///   - Memory-first. The on-disk file is loaded once at first access and
///     mutations operate on the in-memory cache. Writes are debounced so a
///     burst of `append(...)` calls coalesces into a single disk write —
///     Discord presence/connection events fire often enough that the previous
///     load+encode+write-per-append pattern blocked the main thread.
///   - Callers that need durability (app shutdown, clear, log inspection in
///     tests) can call `flush()` to write any pending changes synchronously.
///   - All disk ops run on the store's serial queue.
final class DiscordDiagnosticsStore: @unchecked Sendable {
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let fileURL: URL
  private let queue = DispatchQueue(label: "com.nichtlegacy.ILoveMusic.discord-diagnostics")
  private let maxEntries: Int
  private let logger = Logger(subsystem: AppIdentity.logSubsystem, category: "DiscordDiagnosticsStore")
  private let flushDebounce: DispatchTimeInterval
  private var _lastOutcome: ControlDiagnosticsStoreOutcome = .idle
  private var entries: [ControlLogEntry] = []
  private var hasLoadedFromDisk = false
  private var dirty = false
  private var flushScheduled = false
  var onChange: (@Sendable () -> Void)?

  init(
    fileManager: FileManager = .default,
    supportDirectoryURL: URL? = nil,
    maxEntries: Int = 120,
    flushDebounce: DispatchTimeInterval = .seconds(10)
  ) {
    self.encoder = JSONEncoder()
    self.decoder = JSONDecoder()
    self.maxEntries = maxEntries
    self.flushDebounce = flushDebounce
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    decoder.dateDecodingStrategy = .iso8601

    let baseURL = supportDirectoryURL ?? AppSupportPaths.supportDirectory(fileManager: fileManager)
    self.fileURL = baseURL.appendingPathComponent("discord-log.json", isDirectory: false)
  }

  var lastOutcome: ControlDiagnosticsStoreOutcome {
    queue.sync { _lastOutcome }
  }

  func load() -> [ControlLogEntry] {
    queue.sync {
      ensureLoadedOnQueue()
      return entries
    }
  }

  func append(
    area: String,
    severity: ControlLogSeverity,
    message: String
  ) {
    queue.sync {
      ensureLoadedOnQueue()
      entries.append(ControlLogEntry(area: area, severity: severity, message: message))
      if entries.count > maxEntries {
        entries.removeFirst(entries.count - maxEntries)
      }
      dirty = true
      scheduleFlushOnQueue()
    }
    onChange?()
  }

  func clear() {
    queue.sync {
      ensureLoadedOnQueue()
      entries.removeAll()
      dirty = true
      flushScheduled = false
      saveOnQueue(entries)
      dirty = false
    }
    onChange?()
  }

  /// Synchronously persist any pending changes. Safe to call from a shutdown
  /// hook on the main actor; the actual write happens on the store's queue.
  func flush() {
    queue.sync {
      flushNowOnQueue()
    }
  }

  private func ensureLoadedOnQueue() {
    guard !hasLoadedFromDisk else { return }
    entries = loadFromDiskOnQueue()
    hasLoadedFromDisk = true
  }

  private func scheduleFlushOnQueue() {
    guard !flushScheduled else { return }
    flushScheduled = true
    queue.asyncAfter(deadline: .now() + flushDebounce) { [weak self] in
      guard let self else { return }
      self.flushScheduled = false
      self.flushNowOnQueue()
    }
  }

  private func flushNowOnQueue() {
    guard dirty else { return }
    saveOnQueue(entries)
    dirty = false
  }

  private func loadFromDiskOnQueue() -> [ControlLogEntry] {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      _lastOutcome = .loaded(count: 0)
      return []
    }

    let data: Data
    do {
      data = try Data(contentsOf: fileURL)
    } catch {
      _lastOutcome = .loadFailed(reason: error.localizedDescription)
      logger.error("load: read failed for discord-log.json: \(error.localizedDescription, privacy: .public)")
      return []
    }

    do {
      let loaded = try decoder.decode([ControlLogEntry].self, from: data)
      _lastOutcome = .loaded(count: loaded.count)
      return loaded
    } catch {
      _lastOutcome = .loadFailed(reason: error.localizedDescription)
      logger.error("load: decode failed for discord-log.json: \(error.localizedDescription, privacy: .public)")
      return []
    }
  }

  private func saveOnQueue(_ entries: [ControlLogEntry]) {
    let data: Data
    do {
      data = try encoder.encode(entries)
    } catch {
      _lastOutcome = .saveFailed(reason: error.localizedDescription)
      logger.error("save: encode failed: \(error.localizedDescription, privacy: .public)")
      return
    }

    do {
      try data.write(to: fileURL, options: .atomic)
      _lastOutcome = .saved(count: entries.count)
    } catch {
      _lastOutcome = .saveFailed(reason: error.localizedDescription)
      logger.error("save: write failed for discord-log.json: \(error.localizedDescription, privacy: .public)")
    }
  }
}
