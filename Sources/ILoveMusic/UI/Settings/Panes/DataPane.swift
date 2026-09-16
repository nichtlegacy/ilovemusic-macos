import SwiftUI

struct DataPane: View {
  @Bindable var appModel: AppModel
  @State private var showResetHistoryConfirmation = false

  var body: some View {
    PrefsScrollPane {
      SettingsBlock("Status") {
        DataStatusList(appModel: appModel)
      }

      Divider()

      SettingsBlock("History") {
        PreferenceToggleRow(
          title: "Record listening history",
          subtitle: "Stores tracks you listen to locally on this Mac. When disabled, no new entries are written, and the History & Stats button is hidden from the menu footer.",
          isOn: $appModel.recordHistoryEnabled
        )

        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 8) {
            Button("Reset history…") {
              showResetHistoryConfirmation = true
            }
            .disabled(appModel.historyRecorder.events.isEmpty)
            Text("Deletes the local listening history immediately.")
              .font(.footnote)
              .foregroundStyle(.tertiary)
          }
        }
      }

      Divider()

      SettingsBlock("Actions") {
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 8) {
            Button("Refresh now") { Task { await appModel.refreshAll() } }
            Button("Clear cached catalog") { Task { await appModel.clearCachedCatalog() } }
            Button("Clear cached artwork") { appModel.clearCachedArtwork() }
          }
          Text("Catalog refreshes automatically every 15 minutes. Listeners every 2 minutes. Now-playing every 30 seconds.")
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
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

struct DataStatusList: View {
  let appModel: AppModel

  var body: some View {
    DataRow(label: "Source", value: appModel.source.title)
    DataRow(label: "Last refresh", value: appModel.lastRefreshAt?.shortTimeOrDateTime ?? "Never")
    DataRow(label: "Visible stations", value: "\(appModel.diagnostics.visibleStationCount)")
    DataRow(label: "Filtered out", value: "\(appModel.diagnostics.filteredOutCount)")
  }
}
