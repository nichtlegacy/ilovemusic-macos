import AppKit
import SwiftUI

struct AboutPane: View {
  let appModel: AppModel

  var body: some View {
    PrefsScrollPane {
      AboutHeader()

      Divider()

      SettingsBlock("Updates") {
        UpdatesSection()
      }

      Divider()

      SettingsBlock("Diagnostics") {
        DiagnosticsList(appModel: appModel)
      }

      HStack {
        Spacer()
        Text("© 2026 nichtlegacy")
          .font(.footnote)
          .foregroundStyle(.secondary)
        Spacer()
      }
      .padding(.top, 4)
    }
  }
}

@MainActor
struct AboutHeader: View {
  @State private var iconHover = false

  private static let projectURL = URL(string: "https://github.com/nichtlegacy/ilovemusic_mac")!

  private var versionString: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    return build.map { "\(version) (\($0))" } ?? version
  }

  private var buildTimestamp: String? {
    guard let raw = Bundle.main.object(forInfoDictionaryKey: "ILoveMusicBuildTimestamp") as? String else { return nil }
    let parser = ISO8601DateFormatter()
    parser.formatOptions = [.withInternetDateTime]
    guard let date = parser.date(from: raw) else { return raw }
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    formatter.locale = .current
    return formatter.string(from: date)
  }

  var body: some View {
    VStack(spacing: 12) {
      Button(action: openProjectHome) {
        logoView
          .scaleEffect(iconHover ? 1.05 : 1.0)
          .shadow(color: iconHover ? .accentColor.opacity(0.25) : .clear, radius: 6)
      }
      .buttonStyle(.plain)
      .onHover { hovering in
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
          iconHover = hovering
        }
      }

      VStack(spacing: 2) {
        Text("ILoveMusic Menubar")
          .font(.title3.weight(.semibold))
        Text("Version \(versionString)")
          .font(.callout)
          .foregroundStyle(.secondary)
        if let buildTimestamp {
          Text("Built \(buildTimestamp)")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        Text("Native macOS menu bar player for the public ILoveMusic radio streams.")
          .font(.footnote)
          .foregroundStyle(.tertiary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 24)
      }

      VStack(alignment: .leading, spacing: 6) {
        AboutLinkRow(icon: "chevron.left.slash.chevron.right", title: "GitHub", url: Self.projectURL.absoluteString)
        AboutLinkRow(icon: "globe", title: "ILOVEMUSIC.DE", url: "https://ilovemusic.de/")
      }
      .padding(.top, 4)
    }
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private var logoView: some View {
    if let image = Bundle.module.image(forResource: "AppLogo") {
      Image(nsImage: image)
        .resizable()
        .scaledToFill()
        .frame(width: 92, height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    } else {
      ZStack {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
          .frame(width: 92, height: 92)
        Text("I♥")
          .font(.system(size: 40, weight: .black))
          .foregroundStyle(.white)
      }
    }
  }

  private func openProjectHome() {
    NSWorkspace.shared.open(Self.projectURL)
  }
}

@MainActor
struct UpdatesSection: View {
  @ObservedObject private var updater = UpdaterManager.shared

  private var lastCheckedText: String {
    guard let date = updater.lastUpdateCheckDate else { return "Never" }
    return date.shortTimeOrDateTime
  }

  var body: some View {
    PreferenceToggleRow(
      title: "Check for updates automatically",
      subtitle: "Looks for a new release in the background and asks before installing.",
      isOn: Binding(
        get: { updater.automaticallyChecksForUpdates },
        set: { updater.automaticallyChecksForUpdates = $0 }
      )
    )

    PreferenceToggleRow(
      title: "Download updates in the background",
      subtitle: "Fetches the release ahead of time so installing is instant.",
      isOn: Binding(
        get: { updater.automaticallyDownloadsUpdates },
        set: { updater.automaticallyDownloadsUpdates = $0 }
      )
    )

    DataRow(label: "Last checked", value: lastCheckedText)

    HStack {
      Button("Check for Updates…") {
        updater.checkForUpdates()
      }
      .disabled(!updater.canCheckForUpdates)
      Spacer()
    }
  }
}

struct DiagnosticsList: View {
  let appModel: AppModel

  var body: some View {
    DataRow(label: "Catalog source", value: appModel.diagnostics.source.title)
    DataRow(label: "Raw stations", value: "\(appModel.diagnostics.rawStationCount)")
    DataRow(label: "Visible stations", value: "\(appModel.diagnostics.visibleStationCount)")
    DataRow(label: "Active station", value: appModel.diagnostics.activeStationName ?? "None")
    DataRow(label: "Last metadata", value: appModel.diagnostics.lastMetadataRefreshAt?.shortTimeOrDateTime ?? "Never")
    DataRow(label: "Artwork cleared", value: appModel.diagnostics.lastArtworkCacheClearAt?.shortTimeOrDateTime ?? "Never")
  }
}

struct AboutLinkRow: View {
  let icon: String
  let title: String
  let url: String
  @State private var hovering = false

  var body: some View {
    Button {
      if let url = URL(string: url) { NSWorkspace.shared.open(url) }
    } label: {
      HStack(spacing: 8) {
        Image(systemName: icon)
          .frame(width: 18, alignment: .center)
        Text(title).underline(hovering, color: .accentColor)
        Spacer()
      }
      .padding(.vertical, 4)
      .foregroundColor(.accentColor)
    }
    .buttonStyle(.plain)
    .contentShape(Rectangle())
    .onHover { hovering = $0 }
  }
}
