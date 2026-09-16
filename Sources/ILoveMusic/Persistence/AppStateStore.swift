import Foundation
import os

/// Observable outcome of the most recent `AppStateStore.load()` call.
///
/// Persistence stays best-effort (the app must not crash on a bad
/// `state.json`), but every load case is now distinguishable for tests,
/// diagnostics, and future UI surfaces.
enum AppStateLoadOutcome: Equatable, Sendable {
  /// `state.json` did not exist yet — expected on first launch.
  case missingFile
  /// `state.json` decoded successfully into `PersistedAppState`.
  case loaded
  /// `state.json` existed but could not be decoded. The store has fallen
  /// back to `PersistedAppState.default` and quarantined the bad file at
  /// `quarantinedURL` so it can be inspected later.
  case decodeFailed(reason: String, quarantinedURL: URL?)
  /// `state.json` existed but could not be read at all (permissions,
  /// I/O error). The store has fallen back to `PersistedAppState.default`.
  case readFailed(reason: String)
}

/// Observable outcome of the most recent `AppStateStore.save()` call.
enum AppStateSaveOutcome: Equatable, Sendable {
  case notAttempted
  case saved
  case encodeFailed(reason: String)
  case writeFailed(reason: String)
}

enum AppStateWriteMode: Sendable {
  case immediate
  case queued
}

/// Reads and writes the canonical `state.json` document for the app.
///
/// Contract:
///   - File: `<Application Support>/ILoveMusic/state.json`.
///   - Encoded JSON, pretty-printed with sorted keys, ISO-8601 dates.
///   - Atomic writes (`Data.write(options: .atomic)`).
///   - Load failures never throw to the caller: the store returns
///     `PersistedAppState.default` and records the reason in
///     `lastLoadOutcome` plus an `os.Logger` line. Decode corruption is
///     quarantined to `state.<ISO>.corrupted.json` so manual recovery is
///     possible.
final class AppStateStore: @unchecked Sendable {
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let fileURL: URL
  private let fileManager: FileManager
  private let writeMode: AppStateWriteMode
  private let logger = Logger(subsystem: AppIdentity.logSubsystem, category: "AppStateStore")
  private let ioQueue = DispatchQueue(label: "com.nichtlegacy.ILoveMusic.app-state-store")

  private let queuedWriteDelay: DispatchTimeInterval = .milliseconds(200)
  private var pendingState: PersistedAppState?
  private var queuedWriteScheduled = false

  private(set) var lastLoadOutcome: AppStateLoadOutcome = .missingFile
  private(set) var lastSaveOutcome: AppStateSaveOutcome = .notAttempted

  init(
    fileManager: FileManager = .default,
    supportDirectoryURL: URL? = nil,
    writeMode: AppStateWriteMode = .queued
  ) {
    self.fileManager = fileManager
    self.writeMode = writeMode

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    self.encoder = encoder

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder

    let baseURL = supportDirectoryURL
      ?? AppSupportPaths.supportDirectory(fileManager: fileManager)
    self.fileURL = baseURL.appendingPathComponent("state.json")
  }

  /// Returns the persisted state, falling back to defaults on any error.
  /// Call sites are unchanged from the previous `try?`-based contract;
  /// the difference is that failures are now logged and the reason is
  /// available via `lastLoadOutcome`.
  func load() -> PersistedAppState {
    ioQueue.sync {
      flushPendingSaveLocked()
      return loadLocked()
    }
  }

  /// Persists the supplied state. Records the outcome in `lastSaveOutcome`
  /// and logs failures. Queued writes keep JSON encoding and file I/O off
  /// the main actor and coalesce short bursts into one write.
  func save(_ state: PersistedAppState) {
    switch writeMode {
    case .immediate:
      ioQueue.sync {
        saveLocked(state)
      }
    case .queued:
      ioQueue.async { [weak self] in
        guard let self else { return }
        self.pendingState = state
        guard !self.queuedWriteScheduled else { return }
        self.queuedWriteScheduled = true
        self.ioQueue.asyncAfter(deadline: .now() + self.queuedWriteDelay) { [weak self] in
          guard let self else { return }
          self.flushPendingSaveLocked()
        }
      }
    }
  }

  func flushPendingWrites() {
    ioQueue.sync {
      flushPendingSaveLocked()
    }
  }

  func clearCatalogCache() {
    var state = load()
    state.cachedStations = []
    state.cachedNowPlaying = [:]
    state.lastRefreshAt = nil
    save(state)
  }

  /// Moves the existing `state.json` aside with a timestamp suffix so a
  /// developer can inspect it. Returns the new URL on success, `nil` if
  /// the move itself failed (in which case the original file is left in
  /// place and we still fall back to defaults).
  private func quarantineCorruptedFile() -> URL? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let stamp = formatter.string(from: Date())
      .replacingOccurrences(of: ":", with: "-")
    let target = fileURL
      .deletingLastPathComponent()
      .appendingPathComponent("state.\(stamp).corrupted.json")
    do {
      try fileManager.moveItem(at: fileURL, to: target)
      return target
    } catch {
      logger.error("quarantine: failed to move corrupted state.json: \(error.localizedDescription, privacy: .public)")
      return nil
    }
  }

  private func loadLocked() -> PersistedAppState {
    guard fileManager.fileExists(atPath: fileURL.path) else {
      lastLoadOutcome = .missingFile
      logger.info("load: no state.json yet, using defaults")
      return .default
    }

    let data: Data
    do {
      data = try Data(contentsOf: fileURL)
    } catch {
      lastLoadOutcome = .readFailed(reason: error.localizedDescription)
      logger.error("load: failed to read state.json: \(error.localizedDescription, privacy: .public)")
      return .default
    }

    do {
      let state = try decoder.decode(PersistedAppState.self, from: data)
      lastLoadOutcome = .loaded
      return state
    } catch {
      let quarantined = quarantineCorruptedFile()
      lastLoadOutcome = .decodeFailed(reason: error.localizedDescription, quarantinedURL: quarantined)
      if let quarantined {
        logger.error("load: state.json corrupted (\(error.localizedDescription, privacy: .public)); quarantined to \(quarantined.lastPathComponent, privacy: .public)")
      } else {
        logger.error("load: state.json corrupted (\(error.localizedDescription, privacy: .public)); quarantine failed")
      }
      return .default
    }
  }

  private func saveLocked(_ state: PersistedAppState) {
    let data: Data
    do {
      data = try encoder.encode(state)
    } catch {
      lastSaveOutcome = .encodeFailed(reason: error.localizedDescription)
      logger.error("save: encode failed: \(error.localizedDescription, privacy: .public)")
      return
    }

    do {
      try data.write(to: fileURL, options: .atomic)
      // An atomic write replaces the file, so the mode has to be reapplied each
      // time. state.json holds preferences and listening history metadata and
      // should not be world-readable, matching play_events.jsonl and control.json.
      try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
      lastSaveOutcome = .saved
    } catch {
      lastSaveOutcome = .writeFailed(reason: error.localizedDescription)
      logger.error("save: write failed for \(self.fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
    }
  }

  private func flushPendingSaveLocked() {
    guard let state = pendingState else {
      queuedWriteScheduled = false
      return
    }

    pendingState = nil
    queuedWriteScheduled = false
    saveLocked(state)
  }
}
