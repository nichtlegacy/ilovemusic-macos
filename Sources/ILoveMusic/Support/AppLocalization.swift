import Foundation

extension AppLanguage {
  /// Uses the selected UI language while retaining the user's regional
  /// calendar, number, and measurement preferences.
  var resolvedLocale: Locale {
    resolvedLocale(
      regionalBase: .current,
      systemLanguageIdentifier: Bundle.module.preferredLocalizations.first
    )
  }

  func resolvedLocale(
    regionalBase: Locale,
    systemLanguageIdentifier: String?
  ) -> Locale {
    let languageIdentifier: String?
    switch self {
    case .system:
      languageIdentifier = systemLanguageIdentifier
    case .german, .english:
      languageIdentifier = rawValue
    }

    guard let languageIdentifier else { return regionalBase }
    var components = Locale.Components(locale: regionalBase)
    components.languageComponents.languageCode = Locale.LanguageCode(languageIdentifier)
    return Locale(components: components)
  }
}

enum AppLocalization {
  /// Set before SwiftUI/AppKit creates menus or loads framework translations.
  /// The override lasts only for this process; System Default on the next launch
  /// therefore follows macOS again without altering the user's language settings.
  static func configureProcessLanguage(_ language: AppLanguage, defaults: UserDefaults = .standard) {
    guard language != .system else { return }
    var arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
    arguments["AppleLanguages"] = [language.rawValue]
    defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
  }

  static func string(
    _ resource: LocalizedStringResource,
    language: AppLanguage
  ) -> String {
    String(localized: resource.resolved(in: language.resolvedLocale))
  }
}

extension LocalizedStringResource {
  func resolved(in locale: Locale) -> Self {
    var resource = self
    resource.locale = locale
    return resource
  }
}
