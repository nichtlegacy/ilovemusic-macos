import AppKit
import SwiftUI

struct GeneralPane: View {
  @Bindable var appModel: AppModel

  var body: some View {
    PrefsScrollPane {
      SettingsBlock("System") {
        PreferenceToggleRow(
          title: "Launch at login",
          subtitle: "Automatically opens ILoveMusic when you start your Mac.",
          isOn: $appModel.launchAtLogin
        )
        if let message = appModel.launchAtLoginStatus.message {
          Label(message, systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        PreferenceToggleRow(
          title: "Resume last station on launch",
          subtitle: "Reopens the station that was active before quitting.",
          isOn: $appModel.resumeLastStationOnLaunch
        )
        PreferenceToggleRow(
          title: "Show app in Dock",
          subtitle: "Off by default — ILoveMusic lives in the menu bar.",
          isOn: $appModel.showDockIcon
        )
      }

      Divider()

      SettingsBlock("Library") {
        HStack(alignment: .top, spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Channel order").font(.body)
            Text("Popularity sorts by current listener count; Alphabetical sorts by name.")
              .font(.footnote)
              .foregroundStyle(.tertiary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Picker("Sort", selection: $appModel.stationSort) {
            ForEach(StationSortPreference.allCases) { Text($0.title).tag($0) }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .frame(maxWidth: 160)
        }
      }

      Divider()

      SettingsBlock(contentSpacing: 12) {
        HStack {
          Spacer()
          Button("Quit ILoveMusic") { NSApp.terminate(nil) }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .keyboardShortcut("q", modifiers: [.command])
        }
      }
    }
  }
}
