import Foundation

extension AppLanguage {
  /// `nil` means the app follows the effective macOS app language.
  var locale: Locale? {
    switch self {
    case .system: nil
    case .german: Locale(identifier: "de")
    case .english: Locale(identifier: "en")
    }
  }

  var resolvedLocale: Locale { locale ?? .current }
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
