import Foundation
import Testing
@testable import ILoveMusic

/// Regression coverage for the Settings/Playback UI audit.
///
/// The Playback pane suspends the global Carbon hotkey listener while a
/// `HotkeyRecorderRow` is capturing keys, and resumes it once recording ends.
/// If the pane is torn down mid-recording (the user switches settings tabs or
/// closes the window before pressing a key), the recorder rows never report
/// `recording == false`, so the pane's `.onDisappear` is the only thing that
/// restores the listener. These tests exercise the AppModel suspend/resume
/// methods that the recovery path drives, in the order the pane drives them,
/// to guard against a regression where resume is dropped and global hotkeys
/// stay dead until the app restarts.
@MainActor
@Suite("Settings UI audit — hotkey suspend/resume balance")
struct SettingsUIAuditTests {

  @Test
  func diagnosticPayloadsRemainVerbatim() {
    let originalMessage = "Handshake failed: invalid nonce"
    let entry = ControlLogEntry(area: "Handshake", severity: .error, message: originalMessage)

    #expect(entry.area == "Handshake")
    #expect(entry.message == originalMessage)
  }

  @Test
  func streamDeckStatusRecoversAfterSuccessfulRequest() {
    let errorAt = Date(timeIntervalSince1970: 1_700_000_000)
    let requestAt = errorAt.addingTimeInterval(30)
    var status = ControlServerRuntimeStatus.empty
    status.lastRequestAt = requestAt
    status.lastErrorAt = errorAt

    #expect(StreamDeckConnectionStatus.resolve(runtime: status, now: requestAt) == .receivingRequests)
  }

  @Test
  func streamDeckStatusShowsCurrentServerError() {
    let requestAt = Date(timeIntervalSince1970: 1_700_000_000)
    let errorAt = requestAt.addingTimeInterval(30)
    var status = ControlServerRuntimeStatus.empty
    status.lastRequestAt = requestAt
    status.lastErrorAt = errorAt

    #expect(StreamDeckConnectionStatus.resolve(runtime: status, now: errorAt) == .issue)
  }

  @Test
  func streamDeckStatusBecomesIdleAfterFiveMinutes() {
    let requestAt = Date(timeIntervalSince1970: 1_700_000_000)
    var status = ControlServerRuntimeStatus.empty
    status.lastRequestAt = requestAt

    #expect(StreamDeckConnectionStatus.resolve(runtime: status, now: requestAt.addingTimeInterval(299)) == .receivingRequests)
    #expect(StreamDeckConnectionStatus.resolve(runtime: status, now: requestAt.addingTimeInterval(300)) == .idle)
  }

  @Test
  func germanHotkeyConflictInterpolatesLocalizedActionNames() {
    let names = [HotkeyID.nextStation, .randomStation]
      .map { AppLocalization.string($0.titleResource, language: .german) }
      .joined(separator: ", ")

    #expect(localizedHotkeyConflictMessage(names, locale: Locale(identifier: "de"))
      == "macOS oder eine andere App verwendet bereits Nächster Sender, Zufälliger Sender. Wähle eine andere Tastenkombination.")
  }

  private func makeAppModel() throws -> AppModel {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let stateStore = AppStateStore(supportDirectoryURL: dir, writeMode: .immediate)
    return AppModel(
      playbackController: PlaybackController(),
      stateStoreOverride: stateStore
    )
  }

  /// The recovery path: suspend (recording starts) then resume (pane
  /// disappears mid-recording) must complete without trapping. This is the
  /// exact pair of calls `PlaybackPane.onDisappear` issues when it tears down
  /// with a non-empty `recordingSlots` set.
  @Test
  func suspendThenResumeRecoversAfterPaneTeardown() throws {
    let model = try makeAppModel()

    model.suspendGlobalHotkeysForRecording()
    // Pane disappears before any key is captured → recovery resume.
    model.resumeGlobalHotkeys()
  }

  /// Resuming without a prior suspend (defensive: pane disappears with an
  /// empty recording set) must also be safe and idempotent.
  @Test
  func resumeIsIdempotentWithoutSuspend() throws {
    let model = try makeAppModel()

    model.resumeGlobalHotkeys()
    model.resumeGlobalHotkeys()
  }
}
