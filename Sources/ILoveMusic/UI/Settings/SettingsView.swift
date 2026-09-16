import AppKit
import SwiftUI

/// Tab identity for the SwiftUI Settings scene.
enum SettingsTab: String, CaseIterable, Hashable {
  case general
  case playback
  case discord
  case streamdeck
  case data
  case about

  var title: String {
    switch self {
    case .general: return "General"
    case .playback: return "Playback"
    case .discord: return "Discord"
    case .streamdeck: return "Stream Deck"
    case .data: return "Data"
    case .about: return "About"
    }
  }

  var icon: String {
    switch self {
    case .general: return "gearshape"
    case .playback: return "play.circle"
    case .discord: return "gamecontroller.fill"
    case .streamdeck: return "rectangle.3.group.bubble.left"
    case .data: return "internaldrive"
    case .about: return "info.circle"
    }
  }

  /// Shared canvas size for every settings tab. Sized to host the heaviest
  /// pane (Discord — header + 3 toggles + Application ID + 260 pt log) without
  /// resizing the window between tabs.
  static let contentWidth: CGFloat = 600
  static let contentHeight: CGFloat = 700
}

/// Root view for the SwiftUI `Settings` scene.
///
/// Each tab lives in its own file under `UI/Settings/Panes/`. All tabs share
/// a single canvas size (`SettingsTab.contentWidth × contentHeight`) so the
/// host window never resizes between tabs.
@MainActor
struct SettingsView: View {
  let appModel: AppModel
  @State private var selection: SettingsTab = .general

  var body: some View {
    TabView(selection: $selection) {
      GeneralPane(appModel: appModel)
        .tabItem { Label(SettingsTab.general.title, systemImage: SettingsTab.general.icon) }
        .tag(SettingsTab.general)

      PlaybackPane(appModel: appModel)
        .tabItem { Label(SettingsTab.playback.title, systemImage: SettingsTab.playback.icon) }
        .tag(SettingsTab.playback)

      DiscordPane(appModel: appModel)
        .tabItem { Label(SettingsTab.discord.title, systemImage: SettingsTab.discord.icon) }
        .tag(SettingsTab.discord)

      StreamdeckPane(appModel: appModel)
        .tabItem { Label(SettingsTab.streamdeck.title, systemImage: SettingsTab.streamdeck.icon) }
        .tag(SettingsTab.streamdeck)

      DataPane(appModel: appModel)
        .tabItem { Label(SettingsTab.data.title, systemImage: SettingsTab.data.icon) }
        .tag(SettingsTab.data)

      AboutPane(appModel: appModel)
        .tabItem { Label(SettingsTab.about.title, systemImage: SettingsTab.about.icon) }
        .tag(SettingsTab.about)
    }
    .navigationTitle("ILoveMusic")
    .frame(width: SettingsTab.contentWidth, height: SettingsTab.contentHeight)
  }
}
