import SwiftUI

struct DataPane: View {
  @Bindable var appModel: AppModel
  @State private var showResetHistoryConfirmation = false

  private var versionString: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    return build.map { "\(version) (\($0))" } ?? version
  }

  var body: some View {
    Form {
      Section("Catalog") {
        LabeledContent("Source", value: appModel.source.title)
        LabeledContent("Last refresh", value: appModel.lastRefreshAt?.shortTimeOrDateTime ?? "Never")
        LabeledContent("Visible stations", value: "\(appModel.diagnostics.visibleStationCount)")
        LabeledContent("Filtered out", value: "\(appModel.diagnostics.filteredOutCount)")
      }

      Section {
        SettingsToggle(
          "Record listening history",
          subtitle: "Stores tracks you listen to locally on this Mac. When disabled, no new entries are written, and the History & Stats button is hidden from the menu footer.",
          isOn: $appModel.recordHistoryEnabled
        )
        HStack {
          Button("Reset history…") {
            showResetHistoryConfirmation = true
          }
          .disabled(appModel.historyRecorder.events.isEmpty)
          Spacer()
        }
      } header: {
        Text("History")
      } footer: {
        Text("Deletes the local listening history immediately.")
      }

      Section {
        HStack(spacing: 8) {
          Button("Refresh now") { Task { await appModel.refreshAll() } }
            .controlSize(.small)
          Button("Clear cached catalog") { Task { await appModel.clearCachedCatalog() } }
            .controlSize(.small)
          Button("Clear cached artwork") { appModel.clearCachedArtwork() }
            .controlSize(.small)
        }
      } header: {
        Text("Cache")
      } footer: {
        Text("Catalog refreshes automatically every 15 minutes. Listeners every 2 minutes. Now-playing every 30 seconds.")
      }

      Section("Updates") {
        UpdatesSection()
      }

      SettingsDisclosureGroup("Diagnostics") {
        LabeledContent("Catalog source", value: appModel.diagnostics.source.title)
        LabeledContent("Raw stations", value: "\(appModel.diagnostics.rawStationCount)")
        LabeledContent("Visible stations", value: "\(appModel.diagnostics.visibleStationCount)")
        LabeledContent("Active station", value: appModel.diagnostics.activeStationName ?? "None")
        LabeledContent("Last metadata", value: appModel.diagnostics.lastMetadataRefreshAt?.shortTimeOrDateTime ?? "Never")
        LabeledContent("Artwork cleared", value: appModel.diagnostics.lastArtworkCacheClearAt?.shortTimeOrDateTime ?? "Never")
      }

      Section {
        LabeledContent("Version", value: versionString)
        Link("GitHub", destination: URL(string: "https://github.com/nichtlegacy/ilovemusic_mac")!)
        Link("ILOVEMUSIC.DE", destination: URL(string: "https://ilovemusic.de/")!)
      } header: {
        Text("About")
      } footer: {
        Text("© 2026 nichtlegacy · Native macOS menu bar player for the public ILoveMusic radio streams.")
      }
    }
    .settingsFormStyle()
    .confirmationDialog(
      "Reset listening history?",
      isPresented: $showResetHistoryConfirmation,
      titleVisibility: .visible
    ) {
      Button("Reset history", role: .destructive) {
        appModel.resetListeningHistory()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("All locally stored listening events will be removed immediately.")
    }
  }
}

@MainActor
private struct UpdatesSection: View {
  @ObservedObject private var updater = UpdaterManager.shared

  private var lastCheckedText: String {
    guard let date = updater.lastUpdateCheckDate else { return "Never" }
    return date.shortTimeOrDateTime
  }

  var body: some View {
    SettingsToggle(
      "Check for updates automatically",
      subtitle: "Looks for a new release in the background and asks before installing.",
      isOn: Binding(
        get: { updater.automaticallyChecksForUpdates },
        set: { updater.automaticallyChecksForUpdates = $0 }
      )
    )
    SettingsToggle(
      "Download updates in the background",
      subtitle: "Fetches the release ahead of time so installing is instant.",
      isOn: Binding(
        get: { updater.automaticallyDownloadsUpdates },
        set: { updater.automaticallyDownloadsUpdates = $0 }
      )
    )
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
