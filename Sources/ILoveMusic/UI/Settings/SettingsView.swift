import Observation
import SwiftUI

/// Stable identities for the Settings sidebar and persisted selection.
enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
  case general
  case playback
  case discord
  case streamDeck
  case data
  case advanced
  case about

  var id: Self { self }

  static func persistedValue(_ rawValue: String?) -> Self {
    rawValue.flatMap(Self.init(rawValue:)) ?? .general
  }

  var title: String {
    switch self {
    case .general: "General"
    case .playback: "Playback"
    case .discord: "Discord"
    case .streamDeck: "Stream Deck"
    case .data: "Data"
    case .advanced: "Advanced"
    case .about: "About"
    }
  }

  var icon: String {
    switch self {
    case .general: "gearshape"
    case .playback: "play.circle.fill"
    case .discord: "bubble.left.and.bubble.right.fill"
    case .streamDeck: "rectangle.3.group.fill"
    case .data: "externaldrive.fill"
    case .advanced: "wrench.and.screwdriver.fill"
    case .about: "info.circle.fill"
    }
  }

  var iconColor: Color {
    switch self {
    case .general: .gray
    case .playback: .pink
    case .discord: .indigo
    case .streamDeck: .blue
    case .data: .orange
    case .advanced: .purple
    case .about: .teal
    }
  }
}

@MainActor
@Observable
final class SettingsSelection {
  static let storageKey = "settings.selectedTab"

  private let defaults: UserDefaults
  var tab: SettingsTab {
    didSet { defaults.set(tab.rawValue, forKey: Self.storageKey) }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.tab = SettingsTab.persistedValue(defaults.string(forKey: Self.storageKey))
  }
}

/// Root content for the dedicated AppKit-owned Settings window.
@MainActor
struct SettingsView: View {
  let appModel: AppModel
  @Bindable private var selection: SettingsSelection
  let onSelectionChange: (SettingsTab) -> Void

  init(
    appModel: AppModel,
    selection: SettingsSelection,
    onSelectionChange: @escaping (SettingsTab) -> Void = { _ in }
  ) {
    self.appModel = appModel
    self._selection = Bindable(selection)
    self.onSelectionChange = onSelectionChange
  }

  var body: some View {
    HStack(spacing: 0) {
      SettingsSidebar(selection: $selection.tab)
        .frame(width: 220)
      Divider()
      ZStack(alignment: .topLeading) {
        SettingsVisualEffectView(material: .windowBackground)
        detailView
          .frame(maxWidth: 780, maxHeight: .infinity, alignment: .topLeading)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .frame(minWidth: 800, minHeight: 540)
    .onChange(of: selection.tab) { _, tab in
      onSelectionChange(tab)
    }
  }

  @ViewBuilder
  private var detailView: some View {
    switch selection.tab {
    case .general:
      GeneralPane(appModel: appModel)
    case .playback:
      PlaybackPane(appModel: appModel)
    case .discord:
      DiscordPane(appModel: appModel)
    case .streamDeck:
      StreamDeckPane(appModel: appModel)
    case .data:
      DataPane(appModel: appModel)
    case .advanced:
      AdvancedPane(appModel: appModel)
    case .about:
      AboutPane()
    }
  }
}
