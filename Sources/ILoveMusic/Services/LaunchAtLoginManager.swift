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
  var message: String? {
    switch self {
    case .off, .enabled:
      return nil
    case .unavailable:
      return "Only works in an installed app bundle, not when running from source."
    case .failed(let reason):
      return "macOS refused to register the login item: \(reason)"
    }
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
