import Foundation
import Testing
@testable import ILoveMusic

/// Verifies that the @Bindable preference accessors on AppModel
/// (added in Phase 5.1) correctly route through the existing
/// `update*` methods, mutate `preferences`, and persist to disk.
///
/// We exercise the SAME code paths the SettingsView panes drive when
/// the user toggles a checkbox or picks a sort order. These tests do
/// NOT construct any SwiftUI view — they assign to the computed
/// properties directly, which is what `$appModel.X` reduces to.
@MainActor
@Suite("Settings preference bindings round-trip")
struct SettingsBindingTests {

  private func makeTempSupportDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func makeAppModel(stateStore: AppStateStore) -> AppModel {
    AppModel(
      playbackController: PlaybackController(),
      stateStoreOverride: stateStore
    )
  }

  private func makeStateStore(supportDirectoryURL: URL) -> AppStateStore {
    AppStateStore(
      supportDirectoryURL: supportDirectoryURL,
      writeMode: .immediate
    )
  }

  @Test
  func launchAtLoginSetterUpdatesPreferenceAndPersists() throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = makeStateStore(supportDirectoryURL: dir)
    let model = makeAppModel(stateStore: store)
    #expect(model.launchAtLogin == false)

    model.launchAtLogin = true
    #expect(model.launchAtLogin == true)
    #expect(model.preferences.launchAtLogin == true)

    // Re-load from disk: the change must have been persisted.
    let reloaded = makeStateStore(supportDirectoryURL: dir).load()
    #expect(reloaded.preferences.launchAtLogin == true)
  }

  @Test
  func stationSortBindingPropagates() throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = makeStateStore(supportDirectoryURL: dir)
    let model = makeAppModel(stateStore: store)
    #expect(model.stationSort == .popularity)

    model.stationSort = .alphabetical
    #expect(model.preferences.stationSort == .alphabetical)

    let reloaded = makeStateStore(supportDirectoryURL: dir).load()
    #expect(reloaded.preferences.stationSort == .alphabetical)
  }

  @Test
  func recordHistoryEnabledDefaultsTrueWhenAbsent() throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = makeStateStore(supportDirectoryURL: dir)
    let model = makeAppModel(stateStore: store)

    // UserPreferences.default already sets recordHistoryEnabled = true.
    #expect(model.recordHistoryEnabled == true)
    model.recordHistoryEnabled = false
    #expect(model.preferences.recordHistoryEnabled == false)
  }

  @Test
  func discordOptionalDefaultsAreApplied() throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = makeStateStore(supportDirectoryURL: dir)
    let model = makeAppModel(stateStore: store)

    // Defaults: discordEnabled = false, showArtwork/showButton = true.
    #expect(model.discordEnabled == false)
    #expect(model.discordShowArtwork == true)
    #expect(model.discordShowButton == true)
    #expect(model.discordShowListeners == true)
    #expect(model.discordShowStationLogo == true)
    #expect(model.discordClientID == "")

    model.discordEnabled = true
    model.discordShowArtwork = false
    model.discordShowListeners = false
    model.discordShowStationLogo = false
    model.discordClientID = "1234567890"

    #expect(model.preferences.discordEnabled == true)
    #expect(model.preferences.discordShowArtwork == false)
    #expect(model.preferences.discordShowListeners == false)
    #expect(model.preferences.discordShowStationLogo == false)
    #expect(model.preferences.discordClientID == "1234567890")

    // Cleanup the Discord manager started by enabling discordEnabled = true.
    model.discordManager.stop()
  }

  @Test
  func unlockMaxVolumeSetterRoundTrips() throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = makeStateStore(supportDirectoryURL: dir)
    let model = makeAppModel(stateStore: store)

    // Default: capped (locked).
    #expect(model.unlockMaxVolume == false)

    model.unlockMaxVolume = true
    #expect(model.preferences.unlockMaxVolume == true)

    model.unlockMaxVolume = false
    #expect(model.preferences.unlockMaxVolume == false)
  }

  @Test
  func globalHotkeysEnabledSetterRoundTrips() throws {
    let dir = try makeTempSupportDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = makeStateStore(supportDirectoryURL: dir)
    let model = makeAppModel(stateStore: store)
    // Default is true.
    #expect(model.globalHotkeysEnabled == true)

    model.globalHotkeysEnabled = false
    #expect(model.preferences.globalHotkeysEnabled == false)
    model.globalHotkeysEnabled = true
    #expect(model.preferences.globalHotkeysEnabled == true)
  }
}
