import Foundation
import os

enum ControlLogSeverity: String, Codable, Sendable {
  case info
  case warning
  case error
}

struct ControlLogEntry: Codable, Equatable, Identifiable, Sendable {
  let id: UUID
  let timestamp: Date
  let area: String
  let severity: ControlLogSeverity
  let message: String

  init(
    id: UUID = UUID(),
    timestamp: Date = .now,
    area: String,
    severity: ControlLogSeverity,
    message: String
  ) {
    self.id = id
    self.timestamp = timestamp
    self.area = area
    self.severity = severity
    self.message = message
  }
}

/// Observable outcome of the most recent disk operation on `control-log.json`.
enum ControlDiagnosticsStoreOutcome: Equatable, Sendable {
  case idle
  case loaded(count: Int)
  case loadFailed(reason: String)
  case saved(count: Int)
  case saveFailed(reason: String)
}

/// Append-only rolling diagnostic log for the loopback `ControlServer`.
///
/// Contract:
///   - File: `<Application Support>/ILoveMusic/control-log.json`.
///   - JSON array of `ControlLogEntry`, ISO-8601 timestamps.
///   - Atomic writes (`Data.write(options: .atomic)`).
///   - Capped at `maxEntries` (default 80); oldest entries fall off first.
///
/// Behavior:
///   - Memory-first. The on-disk file is loaded once at first access and
///     mutations operate on the in-memory cache. Writes are debounced so a
///     burst of `append(...)` calls coalesces into a single disk write.
///   - Callers that need durability (app shutdown, clear, log inspection in
///     tests) can call `flush()` to write any pending changes synchronously.
///   - All disk ops still run on the store's serial queue.
final class ControlDiagnosticsStore: @unchecked Sendable {
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let fileURL: URL
  private let queue = DispatchQueue(label: "com.nichtlegacy.ILoveMusic.control-diagnostics")
  private let maxEntries: Int
  private let logger = Logger(subsystem: AppIdentity.logSubsystem, category: "ControlDiagnosticsStore")
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
    maxEntries: Int = 80,
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
    self.fileURL = baseURL.appendingPathComponent("control-log.json", isDirectory: false)
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
      logger.error("load: read failed for control-log.json: \(error.localizedDescription, privacy: .public)")
      return []
    }

    do {
      let loaded = try decoder.decode([ControlLogEntry].self, from: data)
      _lastOutcome = .loaded(count: loaded.count)
      return loaded
    } catch {
      _lastOutcome = .loadFailed(reason: error.localizedDescription)
      logger.error("load: decode failed for control-log.json: \(error.localizedDescription, privacy: .public)")
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
      logger.error("save: write failed for control-log.json: \(error.localizedDescription, privacy: .public)")
    }
  }
}
