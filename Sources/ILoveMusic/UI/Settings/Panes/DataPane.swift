import SwiftUI

struct DataPane: View {
  @Environment(\.locale) private var locale
  @Bindable var appModel: AppModel
  @State private var showResetHistoryConfirmation = false

  var body: some View {
    Form {
      Section {
        LabeledContent { Text(appModel.source.titleResource.resolved(in: locale)) } label: { Text("Source", bundle: #bundle) }
        LabeledContent {
          if let date = appModel.lastRefreshAt { Text(verbatim: date.shortTimeOrDateTime(locale: locale)) } else { Text("Never", bundle: #bundle) }
        } label: { Text("Last refresh", bundle: #bundle) }
        LabeledContent { Text(verbatim: "\(appModel.diagnostics.visibleStationCount)") } label: { Text("Visible stations", bundle: #bundle) }
        LabeledContent { Text(verbatim: "\(appModel.diagnostics.filteredOutCount)") } label: { Text("Filtered out", bundle: #bundle) }
      } header: {
        Text("Catalog", bundle: #bundle)
      }

      Section {
        SettingsToggle(
          LocalizedStringResource("Record listening history", bundle: #bundle, comment: "Settings toggle"),
          subtitle: LocalizedStringResource("Stores tracks you listen to locally on this Mac. When disabled, no new entries are written, and the History & Stats button is hidden from the menu footer.", bundle: #bundle, comment: "Listening history setting explanation"),
          isOn: $appModel.recordHistoryEnabled
        )
        HStack {
          Button {
            showResetHistoryConfirmation = true
          } label: {
            Text("Reset history…", bundle: #bundle)
          }
          .disabled(appModel.historyRecorder.events.isEmpty)
          Spacer()
        }
      } header: {
        Text("History", bundle: #bundle)
      } footer: {
        Text("Deletes the local listening history immediately.", bundle: #bundle)
      }
    }
    .settingsFormStyle()
    .confirmationDialog(
      Text("Reset listening history?", bundle: #bundle),
      isPresented: $showResetHistoryConfirmation,
      titleVisibility: .visible
    ) {
      Button(role: .destructive) {
        appModel.resetListeningHistory()
      } label: { Text("Reset history", bundle: #bundle) }
      Button(role: .cancel) {} label: { Text("Cancel", bundle: #bundle) }
    } message: {
      Text("All locally stored listening events will be removed immediately.", bundle: #bundle)
    }
  }
}
