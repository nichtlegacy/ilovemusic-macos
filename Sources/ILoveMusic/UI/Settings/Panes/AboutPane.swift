import AppKit
import SwiftUI

struct AboutPane: View {
  private var version: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
  }

  private var build: String? {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
  }

  var body: some View {
    Form {
      HStack(spacing: 20) {
        Image(nsImage: NSApplication.shared.applicationIconImage)
          .resizable()
          .frame(width: 92, height: 92)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 5) {
          Text(AppIdentity.displayName)
            .font(.title.bold())
          Text(build.map { "Version \(version) (\($0))" } ?? "Version \(version)")
            .foregroundStyle(.secondary)
          Text("A native macOS menu bar player for the public ILoveMusic radio streams.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(.vertical, 10)
      .listRowBackground(Color.clear)

      Section("Updates") {
        UpdatesSection()
      }

      Section {
        Link(destination: URL(string: "https://github.com/nichtlegacy/ilovemusic_mac")!) {
          Label("GitHub", systemImage: "arrow.up.right.square")
        }
        Link(destination: URL(string: "https://ilovemusic.de/")!) {
          Label("ILOVEMUSIC.DE", systemImage: "globe")
        }
      } header: {
        Text("Links")
      } footer: {
        Text("© 2026 nichtlegacy")
      }
    }
    .settingsFormStyle()
  }
}

@MainActor
private struct UpdatesSection: View {
  @ObservedObject private var updater = UpdaterManager.shared

  private var lastCheckedText: String {
    updater.lastUpdateCheckDate?.shortTimeOrDateTime ?? "Never"
  }

  var body: some View {
    SettingsToggle(
      "Check for updates automatically",
      subtitle: "Look for new releases in the background and ask before installing.",
      isOn: Binding(
        get: { updater.automaticallyChecksForUpdates },
        set: { updater.automaticallyChecksForUpdates = $0 }
      )
    )
    SettingsToggle(
      "Download updates in the background",
      subtitle: "Fetch releases ahead of time so they are ready to install.",
      isOn: Binding(
        get: { updater.automaticallyDownloadsUpdates },
        set: { updater.automaticallyDownloadsUpdates = $0 }
      )
    )
    .disabled(!updater.automaticallyChecksForUpdates)
    .opacity(updater.automaticallyChecksForUpdates ? 1 : 0.5)
    LabeledContent("Last checked", value: lastCheckedText)
    HStack {
      Button("Check for Updates…") {
        updater.checkForUpdates()
      }
      .disabled(!updater.canCheckForUpdates)
      Spacer()
    }
  }
}
