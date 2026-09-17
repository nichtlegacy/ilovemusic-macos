import Foundation
import Testing
@testable import ILoveMusic

@Suite("App language")
struct LocalizationTests {
  @Test
  func processLanguageOverrideIsVolatileAndPreservesLaunchArguments() throws {
    let suite = "ILoveMusic.localization.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    let originalArguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
    defer { defaults.setVolatileDomain(originalArguments, forName: UserDefaults.argumentDomain) }
    defaults.setVolatileDomain(["existingArgument": "kept", "AppleLanguages": ["de"]], forName: UserDefaults.argumentDomain)
    AppLocalization.configureProcessLanguage(.system, defaults: defaults)
    #expect(defaults.stringArray(forKey: "AppleLanguages") == ["de"])
    AppLocalization.configureProcessLanguage(.english, defaults: defaults)
    #expect(defaults.stringArray(forKey: "AppleLanguages") == ["en"])
    #expect(defaults.string(forKey: "existingArgument") == "kept")
    #expect(defaults.persistentDomain(forName: suite)?["AppleLanguages"] == nil)
  }

  @Test
  func pluralFormsResolveInBothLanguages() {
    let english = Locale(identifier: "en")
    let german = Locale(identifier: "de")
    #expect(localizedDayCount(1, locale: english) == "1 day")
    #expect(localizedDayCount(2, locale: english) == "2 days")
    #expect(localizedDayCount(1, locale: german) == "1 Tag")
    #expect(localizedDayCount(2, locale: german) == "2 Tage")
    #expect(localizedSongCount(1, locale: english) == "1 song")
    #expect(localizedSongCount(2, locale: english) == "2 songs")
    #expect(localizedSongCount(1, locale: german) == "1 Titel")
    #expect(localizedSongCount(2, locale: german) == "2 Titel")
    #expect(localizedPlayCount(1, locale: english) == "1 play")
    #expect(localizedPlayCount(2, locale: english) == "2 plays")
    #expect(localizedPlayCount(1, locale: german) == "1 Wiedergabe")
    #expect(localizedPlayCount(2, locale: german) == "2 Wiedergaben")
  }

  @Test
  func historyRangeLabelsAreHumanReadable() {
    #expect(AppLocalization.string(HistoryWindow.last7Days.titleResource, language: .german) == "7 Tage")
    #expect(AppLocalization.string(HistoryWindow.last7Days.titleResource, language: .english) == "7 Days")
    #expect(AppLocalization.string(HistoryWindow.lifetime.titleResource, language: .german) == "Gesamter Zeitraum")
  }

  @MainActor
  @Test
  func pendingRestartControlsUseSelectedGermanLanguage() {
    #expect(
      AppLocalization.string(GeneralPane.restartButtonResource, language: .german)
        == "ILoveMusic neu starten"
    )
    #expect(
      AppLocalization.string(GeneralPane.languageRestartNoticeResource, language: .german)
        == "Die Sprache ändert sich nach einem Neustart von ILoveMusic."
    )
  }

  @Test
  func rawValuesAreStable() {
    #expect(AppLanguage.system.rawValue == "system")
    #expect(AppLanguage.german.rawValue == "de")
    #expect(AppLanguage.english.rawValue == "en")
  }

  @Test
  func unknownLanguageFallsBackWithoutThrowing() throws {
    let decoded = try JSONDecoder().decode(
      AppLanguage.self,
      from: Data("\"future-language\"".utf8)
    )
    #expect(decoded == .system)
  }

  @Test
  func missingPreferenceUsesSystemLanguage() throws {
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(UserPreferences.default))
        as? [String: Any]
    )
    object.removeValue(forKey: "appLanguage")
    let data = try JSONSerialization.data(withJSONObject: object)
    let decoded = try JSONDecoder().decode(UserPreferences.self, from: data)

    #expect(decoded.effectiveAppLanguage == .system)
    #expect(decoded.volume == UserPreferences.default.volume)
  }

  @Test(arguments: [AppLanguage.system, .german, .english])
  func preferenceRoundTrips(language: AppLanguage) throws {
    var preferences = UserPreferences.default
    preferences.appLanguage = language

    let decoded = try JSONDecoder().decode(
      UserPreferences.self,
      from: JSONEncoder().encode(preferences)
    )
    #expect(decoded.effectiveAppLanguage == language)
  }

  @Test
  func explicitLanguageKeepsRegionalFormattingPreferences() {
    let locale = AppLanguage.english.resolvedLocale(
      regionalBase: Locale(identifier: "de_DE"),
      systemLanguageIdentifier: nil
    )

    #expect(locale.language.languageCode?.identifier == "en")
    #expect(locale.region?.identifier == "DE")
  }

  @Test
  func systemLanguageUsesPreferredAppLocalizationAndKeepsRegion() {
    let locale = AppLanguage.system.resolvedLocale(
      regionalBase: Locale(identifier: "de_DE"),
      systemLanguageIdentifier: "en"
    )

    #expect(locale.language.languageCode?.identifier == "en")
    #expect(locale.region?.identifier == "DE")
  }

  @MainActor
  @Test
  func changingSavedLanguageRequiresRestart() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = AppStateStore(supportDirectoryURL: directory, writeMode: .immediate)
    var state = PersistedAppState.default
    state.preferences.appLanguage = .english
    store.save(state)

    let model = AppModel(
      playbackController: PlaybackController(),
      stateStoreOverride: store
    )
    #expect(model.activeLanguage == .english)
    #expect(!model.requiresLanguageRestart)

    model.appLanguage = .german
    #expect(model.activeLanguage == .english)
    #expect(model.requiresLanguageRestart)

    model.appLanguage = .english
    #expect(!model.requiresLanguageRestart)
  }

  @Test
  func representativeDomainResourcesResolveInGerman() {
    #expect(AppLocalization.string(StationSortPreference.alphabetical.titleResource, language: .german) == "Alphabetisch")
    #expect(AppLocalization.string(PlaybackPhase.buffering.titleResource, language: .german) == "Wird geladen")
    #expect(AppLocalization.string(HotkeyID.nextStation.titleResource, language: .german) == "Nächster Sender")
    #expect(AppLocalization.string(AppIdentity.historyWindowTitleResource, language: .german) == "ILoveMusic – Verlauf & Statistiken")
  }

  @Test
  func shippingCatalogKeysHaveGermanTranslations() throws {
    let sourceFile = URL(fileURLWithPath: #filePath)
    let repositoryRoot = sourceFile
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let catalogURL = repositoryRoot
      .appendingPathComponent("Sources/ILoveMusic/Resources/Localizable.xcstrings")
    let root = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
    )
    #expect(root["sourceLanguage"] as? String == "en")

    let strings = try #require(root["strings"] as? [String: Any])
    for (key, rawEntry) in strings {
      guard !key.isEmpty else { continue }
      let entry = try #require(rawEntry as? [String: Any], "Malformed catalog entry for \(key)")
      let localizations = try #require(entry["localizations"] as? [String: Any], "Missing localizations for \(key)")
      let german = try #require(localizations["de"] as? [String: Any], "Missing German localization for \(key)")
      #expect(german["stringUnit"] != nil || german["variations"] != nil)
    }
  }
}
