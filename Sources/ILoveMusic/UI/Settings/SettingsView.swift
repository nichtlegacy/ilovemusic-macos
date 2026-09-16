import AppKit
import SwiftUI

/// Tab identity for the SwiftUI Settings scene (sidebar style).
enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
  case general
  case playback
  case integrations
  case data

  var id: Self { self }

  var title: String {
    switch self {
    case .general: return "General"
    case .playback: return "Playback"
    case .integrations: return "Integrations"
    case .data: return "Data"
    }
  }

  var icon: String {
    switch self {
    case .general: return "gearshape"
    case .playback: return "play.circle"
    case .integrations: return "puzzlepiece.extension"
    case .data: return "internaldrive"
    }
  }
}

/// Root view for the SwiftUI `Settings` scene.
///
/// Sidebar + detail (`NavigationSplitView`) with native grouped Forms per tab.
/// No fixed canvas: the window sizes itself, minimum 640×480.
@MainActor
struct SettingsView: View {
  let appModel: AppModel
  @State private var selection: SettingsTab? = .general
  @State private var columnVisibility: NavigationSplitViewVisibility = .all

  private var activeTab: SettingsTab { selection ?? .general }

  private var versionString: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    return build.map { "Version \(version) (\($0))" } ?? "Version \(version)"
  }

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      List(selection: $selection) {
        ForEach(SettingsTab.allCases) { tab in
          Label(tab.title, systemImage: tab.icon)
            .tag(tab)
        }
        HStack(spacing: 8) {
          sidebarLogo
          VStack(alignment: .leading, spacing: 1) {
            Text("ILoveMusic")
              .font(.callout.weight(.semibold))
            Text(versionString)
              .font(.caption)
              .foregroundStyle(.tertiary)
              .monospacedDigit()
          }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .listRowSeparator(.hidden)
      }
      .listStyle(.sidebar)
      .scrollEdgeEffectSoftIfAvailable()
      .navigationTitle("Settings")
      .frame(minWidth: 180)
      .toolbar(removing: .sidebarToggle)
    } detail: {
      Group {
        switch activeTab {
        case .general:
          GeneralPane(appModel: appModel)
        case .playback:
          PlaybackPane(appModel: appModel)
        case .integrations:
          IntegrationsPane(appModel: appModel)
        case .data:
          DataPane(appModel: appModel)
        }
      }
      .navigationTitle(activeTab.title)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .navigationSplitViewStyle(.balanced)
    .frame(minWidth: 640, minHeight: 480)
    .toolbar {
      ToolbarItem(placement: .navigation) {
        Button {
          withAnimation {
            columnVisibility = columnVisibility == .all ? .detailOnly : .all
          }
        } label: {
          Image(systemName: "sidebar.left")
        }
        .help(columnVisibility == .all ? "Hide sidebar" : "Show sidebar")
      }
    }
  }

  @ViewBuilder
  private var sidebarLogo: some View {
    if let image = Bundle.module.image(forResource: "AppLogo") {
      Image(nsImage: image)
        .resizable()
        .scaledToFill()
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    } else {
      ZStack {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
          .frame(width: 36, height: 36)
        Text("I♥")
          .font(.system(size: 16, weight: .black))
          .foregroundStyle(.white)
      }
    }
  }
}
