import SwiftUI

struct DataPane: View {
  @Bindable var appModel: AppModel
  @State private var showResetHistoryConfirmation = false

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
