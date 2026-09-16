import SwiftUI

struct DiscordPane: View {
  @Bindable var appModel: AppModel

  var body: some View {
    Form {
      Section("Connection") {
        LabeledContent("Status") {
          SettingsStatusDot(color: statusColor, label: appModel.discordManager.state.label)
        }
        SettingsToggle(
          "Enable Discord Rich Presence",
          subtitle: "Show your current ILoveMusic station and song in your Discord profile.",
          isOn: $appModel.discordEnabled
        )
        if case .error(let message) = appModel.discordManager.state {
          Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.red)
        }
      }

      Section {
        SettingsToggle(
          "Include current song artwork",
          subtitle: "Send the cover image of the song currently playing.",
          isOn: $appModel.discordShowArtwork
        )
        SettingsToggle(
          "Include Listen button",
          subtitle: "Add a button to your profile that opens the station on ilovemusic.de.",
          isOn: $appModel.discordShowButton
        )
        SettingsToggle(
          "Include current listeners",
          subtitle: "Show the station's live listener count next to the channel name.",
          isOn: $appModel.discordShowListeners
        )
        SettingsToggle(
          "Show station logo badge",
          subtitle: "Display the I Love Radio logo as the small artwork badge.",
          isOn: $appModel.discordShowStationLogo
        )
        LabeledContent("Application ID") {
          TextField(
            "Application ID",
            text: $appModel.discordClientID,
            prompt: Text("e.g. 1234567890123456789")
          )
          .textFieldStyle(.roundedBorder)
          .labelsHidden()
          .disableAutocorrection(true)
          .frame(minWidth: 220)
        }
      } header: {
        Text("Rich Presence")
      } footer: {
        Text("Create an application at developer.discord.com, then copy its Application ID here.")
      }
      .disabled(!appModel.discordEnabled)
      .opacity(appModel.discordEnabled ? 1 : 0.5)
    }
    .settingsFormStyle()
  }

  private var statusColor: Color {
    switch appModel.discordManager.state {
    case .connected: .green
    case .connecting: .orange
    case .error: .red
    case .disconnected: .secondary
    }
  }
}
