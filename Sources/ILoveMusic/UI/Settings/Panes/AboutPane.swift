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
          Text(verbatim: AppIdentity.displayName)
            .font(.title.bold())
          Group {
            if let build {
              Text("Version \(version) (\(build))", bundle: #bundle)
            } else {
              Text("Version \(version)", bundle: #bundle)
            }
          }
          .foregroundStyle(.secondary)
          Text("A native macOS menu bar player for the public ILoveMusic radio streams.", bundle: #bundle)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(.vertical, 10)
      .listRowBackground(Color.clear)

      Section {
        UpdatesSection()
      } header: {
        Text("Updates", bundle: #bundle)
      }

      Section {
        Link(destination: URL(string: "https://github.com/nichtlegacy/ilovemusic-macos")!) {
          Label("GitHub", systemImage: "arrow.up.right.square")
        }
        Link(destination: URL(string: "https://ilovemusic.de/")!) {
          Label("ILOVEMUSIC.DE", systemImage: "globe")
        }
      } header: {
        Text("Links", bundle: #bundle)
      } footer: {
        Text(verbatim: "© 2026 nichtlegacy")
      }
    }
    .settingsFormStyle()
  }
}

@MainActor
private struct UpdatesSection: View {
  @Environment(\.locale) private var locale
  @ObservedObject private var updater = UpdaterManager.shared

  private var lastCheckedText: Text {
    if let date = updater.lastUpdateCheckDate {
      return Text(verbatim: date.shortTimeOrDateTime(locale: locale))
    }
    return Text("Never", bundle: #bundle)
  }

  var body: some View {
    SettingsToggle(
      LocalizedStringResource("Check for updates automatically", bundle: #bundle, comment: "Settings toggle"),
      subtitle: LocalizedStringResource("Look for new releases in the background and ask before installing.", bundle: #bundle, comment: "Automatic update checks explanation"),
      isOn: Binding(
        get: { updater.automaticallyChecksForUpdates },
        set: { updater.automaticallyChecksForUpdates = $0 }
      )
    )
    SettingsToggle(
      LocalizedStringResource("Download updates in the background", bundle: #bundle, comment: "Settings toggle"),
      subtitle: LocalizedStringResource("Fetch releases ahead of time so they are ready to install.", bundle: #bundle, comment: "Automatic update downloads explanation"),
      isOn: Binding(
        get: { updater.automaticallyDownloadsUpdates },
        set: { updater.automaticallyDownloadsUpdates = $0 }
      )
    )
    .disabled(!updater.automaticallyChecksForUpdates)
    .opacity(updater.automaticallyChecksForUpdates ? 1 : 0.5)
    LabeledContent {
      lastCheckedText
    } label: {
      Text("Last checked", bundle: #bundle)
    }
    HStack {
      Button {
        updater.checkForUpdates()
      } label: {
        Text("Check for Updates…", bundle: #bundle)
      }
      .disabled(!updater.canCheckForUpdates)
      Spacer()
    }
  }
}
