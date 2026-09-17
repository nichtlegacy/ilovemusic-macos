import AppKit
import Foundation
import Testing
@testable import ILoveMusic

@MainActor
@Suite("Settings navigation")
struct SettingsNavigationTests {
  @Test
  func tabsHaveStableOrder() {
    #expect(SettingsTab.allCases == [
      .general, .playback, .discord, .streamDeck, .data, .advanced, .about,
    ])
  }

  @Test
  func settingsTabTitlesResolveInGerman() {
    #expect(AppLocalization.string(SettingsTab.general.titleResource, language: .german) == "Allgemein")
    #expect(AppLocalization.string(SettingsTab.advanced.titleResource, language: .german) == "Erweitert")
  }

  @Test
  func unknownPersistedSelectionFallsBackToGeneral() {
    #expect(SettingsTab.persistedValue("discord") == .discord)
    #expect(SettingsTab.persistedValue("removed-pane") == .general)
    #expect(SettingsTab.persistedValue(nil) == .general)
  }

  @Test
  func selectionPersistsChanges() throws {
    let name = "SettingsNavigationTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }

    let selection = SettingsSelection(defaults: defaults)
    #expect(selection.tab == .general)
    selection.tab = .streamDeck
    #expect(defaults.string(forKey: SettingsSelection.storageKey) == "streamDeck")
    #expect(SettingsSelection(defaults: defaults).tab == .streamDeck)
  }

  @Test
  func settingsWindowUsesTheExpectedChrome() throws {
    let fixture = try makeSettingsTestModel()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let controller = SettingsWindowController(appModel: fixture.model)
    let window = try #require(controller.window)

    #expect(window.styleMask.contains(.fullSizeContentView))
    #expect(window.styleMask.contains(.resizable))
    #expect(window.contentMinSize == NSSize(width: 800, height: 540))
    #expect(window.frameAutosaveName == "settings-window")
    #expect(window.title == AppLocalization.string(SettingsTab.general.titleResource, language: fixture.model.activeLanguage))
  }

  private func makeSettingsTestModel() throws -> (model: AppModel, directory: URL) {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = AppStateStore(supportDirectoryURL: directory, writeMode: .immediate)
    return (AppModel(playbackController: PlaybackController(), stateStoreOverride: store), directory)
  }
}
