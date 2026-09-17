import Foundation
import ServiceManagement

/// Observable launch-at-login state for the settings UI. Distinct from the
/// stored preference, which says what the user asked for rather than what
/// macOS accepted.
enum LaunchAtLoginStatus: Equatable {
  case off
  case enabled
  case unavailable
  case failed(reason: String)

  /// User-facing explanation, or `nil` when there is nothing to report.
  var messageResource: LocalizedStringResource? {
    switch self {
    case .off, .enabled:
      return nil
    case .unavailable:
      return LocalizedStringResource(
        "Only works in an installed app bundle, not when running from source.",
        bundle: #bundle,
        comment: "Launch at login is unavailable while running the app from source."
      )
    case .failed(let reason):
      return LocalizedStringResource(
        "macOS refused to register the login item: \(reason)",
        bundle: #bundle,
        comment: "Launch at login failed. The interpolated system error remains unchanged."
      )
    }
  }

  /// English diagnostic-compatible rendering retained for non-UI callers.
  var message: String? {
    messageResource.map { AppLocalization.string($0, language: .english) }
  }
}

struct LaunchAtLoginManager {
  /// What actually happened when the preference was applied. The caller needs
  /// this because a stored `launchAtLogin = true` that macOS rejected would
  /// otherwise show a checked box for a login item that does not exist.
  enum Outcome: Equatable {
    /// The login item was registered or unregistered as requested.
    case applied
    /// Not running from an .app bundle, so there is nothing to register.
    /// Normal during `swift run`.
    case unavailable
    case failed(reason: String)
  }

  func setEnabled(_ enabled: Bool) -> Outcome {
    guard isBundled else { return .unavailable }

    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      return .applied
    } catch {
      return .failed(reason: error.localizedDescription)
    }
  }

  /// Whether macOS currently has the login item registered. Used to fall back
  /// to the real system state when registration fails.
  var isRegistered: Bool {
    guard isBundled else { return false }
    return SMAppService.mainApp.status == .enabled
  }

  private var isBundled: Bool {
    Bundle.main.bundleURL.pathExtension == "app"
  }
}
