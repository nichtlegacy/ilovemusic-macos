import Foundation
import os

final class PlayHistoryStore {
  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let fileURL: URL
  private let queue = DispatchQueue(label: "com.nichtlegacy.ILoveMusic.history-store")
  private let logger = Logger(subsystem: "com.nichtlegacy.ILoveMusic", category: "PlayHistoryStore")

  private var fileHandle: FileHandle?

  init(fileManager: FileManager = .default) {
    self.fileManager = fileManager

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    self.encoder = encoder

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder

    let baseURL = AppSupportPaths.supportDirectory(fileManager: fileManager)
    self.fileURL = baseURL.appendingPathComponent("play_events.jsonl", isDirectory: false)
  }

  init(fileURL: URL, fileManager: FileManager = .default) {
    self.fileManager = fileManager

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    self.encoder = encoder

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder

    try? fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    self.fileURL = fileURL
  }

  deinit {
    try? fileHandle?.close()
  }

  func loadAll() -> [PlayEvent] {
    queue.sync {
      let snapshot = readSnapshotLocked()
      if snapshot.isFullyDecoded,
         shouldCompactLocked(lineCount: snapshot.lineCount, uniqueCount: snapshot.events.count) {
        rewriteLocked(events: snapshot.events.values.sorted(by: sortEvents))
      }
      return snapshot.events.values.sorted(by: sortEvents)
    }
  }

  func loadOpenEvents() -> [PlayEvent] {
    loadAll().filter { $0.endedAt == nil }
  }

  func append(_ event: PlayEvent) {
    append(event, flushToDisk: false)
  }

  func deleteAll() {
    queue.sync {
      closeFileHandleLocked()
      try? fileManager.removeItem(at: fileURL)
    }
  }

  func compact() {
    queue.sync {
      let snapshot = readSnapshotLocked()
      // Rewriting a partially decoded file would silently discard the lines
      // this version does not understand. Leave it untouched for recovery or
      // a future migration instead.
      guard snapshot.isFullyDecoded else {
        logger.error("skipping compaction: play history was not fully decoded")
        return
      }
      rewriteLocked(events: snapshot.events.values.sorted(by: sortEvents))
    }
  }

  func compactIfNeeded() {
    queue.sync {
      let snapshot = readSnapshotLocked()
      guard snapshot.isFullyDecoded else { return }
      guard shouldCompactLocked(lineCount: snapshot.lineCount, uniqueCount: snapshot.events.count) else { return }
      rewriteLocked(events: snapshot.events.values.sorted(by: sortEvents))
    }
  }

  func append(_ event: PlayEvent, flushToDisk: Bool) {
    queue.sync {
      ensureFileExistsLocked()
      do {
        let data = try encoder.encode(event)
        var line = Data()
        line.append(data)
        line.append(0x0A)

        let handle = try openHandleLocked()
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
        if flushToDisk {
          try handle.synchronize()
        }
      } catch {
        logger.error("failed to append play event: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  func remove(eventID: UUID) {
    queue.sync {
      var snapshot = readSnapshotLocked()
      guard snapshot.events.removeValue(forKey: eventID) != nil else { return }
      rewriteLocked(events: snapshot.events.values.sorted(by: sortEvents))
    }
  }

  private func readSnapshotLocked() -> (events: [UUID: PlayEvent], lineCount: Int, isFullyDecoded: Bool) {
    guard fileManager.fileExists(atPath: fileURL.path) else {
      return ([:], 0, true)
    }

    let data: Data
    do {
      data = try Data(contentsOf: fileURL)
    } catch {
      logger.error("failed to read history file: \(error.localizedDescription, privacy: .public)")
      return ([:], 0, false)
    }

    guard !data.isEmpty else {
      return ([:], 0, true)
    }

    guard let text = String(data: data, encoding: .utf8) else {
      logger.error("failed to decode history file as UTF-8")
      return ([:], 0, false)
    }

    var events: [UUID: PlayEvent] = [:]
    var lineCount = 0
    var isFullyDecoded = true

    for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
      lineCount += 1
      do {
        let event = try decoder.decode(PlayEvent.self, from: Data(rawLine.utf8))
        events[event.id] = event
      } catch {
        isFullyDecoded = false
        logger.error("failed to decode play event line: \(error.localizedDescription, privacy: .public)")
      }
    }

    return (events, lineCount, isFullyDecoded)
  }

  private func ensureFileExistsLocked() {
    guard !fileManager.fileExists(atPath: fileURL.path) else { return }
    fileManager.createFile(atPath: fileURL.path, contents: nil)
    try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
  }

  private func openHandleLocked() throws -> FileHandle {
    if let fileHandle {
      return fileHandle
    }

    ensureFileExistsLocked()
    let handle = try FileHandle(forWritingTo: fileURL)
    self.fileHandle = handle
    return handle
  }

  private func closeFileHandleLocked() {
    try? fileHandle?.close()
    fileHandle = nil
  }

  private func rewriteLocked(events: [PlayEvent]) {
    let tempURL = fileURL.appendingPathExtension("tmp")
    closeFileHandleLocked()

    let body = events.reduce(into: Data()) { data, event in
      if let encoded = try? encoder.encode(event) {
        data.append(encoded)
        data.append(0x0A)
      }
    }

    do {
      try body.write(to: tempURL, options: .atomic)
      try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tempURL.path)
      if fileManager.fileExists(atPath: fileURL.path) {
        // Keep a backup of the previous file before swapping so a bad rewrite
        // (or a future bug) is always recoverable from play_events.jsonl.bak.
        let backupURL = fileURL.appendingPathExtension("bak")
        try? fileManager.removeItem(at: backupURL)
        try? fileManager.copyItem(at: fileURL, to: backupURL)
        // Atomic swap: never leaves a window where neither file exists, so a
        // failure here cannot wipe the existing history along with the temp.
        _ = try fileManager.replaceItemAt(fileURL, withItemAt: tempURL)
      } else {
        try fileManager.moveItem(at: tempURL, to: fileURL)
      }
    } catch {
      logger.error("failed to rewrite play history file: \(error.localizedDescription, privacy: .public)")
      try? fileManager.removeItem(at: tempURL)
    }
  }

  private func shouldCompactLocked(lineCount: Int, uniqueCount: Int) -> Bool {
    if lineCount > 200 && uniqueCount > 0 && lineCount > uniqueCount * 2 {
      return true
    }

    let fileSize = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.int64Value ?? 0
    return fileSize > 50 * 1024 * 1024
  }

  private func sortEvents(_ lhs: PlayEvent, _ rhs: PlayEvent) -> Bool {
    if lhs.startedAt != rhs.startedAt {
      return lhs.startedAt < rhs.startedAt
    }
    return lhs.id.uuidString < rhs.id.uuidString
  }
}
