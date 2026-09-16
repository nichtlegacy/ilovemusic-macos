import AppKit
import SwiftUI

struct GeneralPane: View {
  @Bindable var appModel: AppModel

  var body: some View {
    Form {
      Section("System") {
        SettingsToggle(
          "Launch at login",
          subtitle: "Automatically opens ILoveMusic when you start your Mac.",
          isOn: $appModel.launchAtLogin
        )
        if let message = appModel.launchAtLoginStatus.message {
          Label(message, systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        SettingsToggle(
          "Resume last station on launch",
          subtitle: "Reopens the station that was active before quitting.",
          isOn: $appModel.resumeLastStationOnLaunch
        )
      }

      Section {
        Picker("Channel order", selection: $appModel.stationSort) {
          ForEach(StationSortPreference.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.menu)
      } header: {
        Text("Library")
      } footer: {
        Text("Popularity sorts by current listener count; Alphabetical sorts by name.")
      }
    }
    .settingsFormStyle()
  }
}
