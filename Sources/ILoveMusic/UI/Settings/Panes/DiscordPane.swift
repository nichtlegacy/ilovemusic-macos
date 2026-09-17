import SwiftUI

struct DiscordPane: View {
  @Bindable var appModel: AppModel

  var body: some View {
    Form {
      Section {
        LabeledContent {
          SettingsStatusDot(color: statusColor, label: appModel.discordManager.state.label)
        } label: {
          Text("Status", bundle: #bundle)
        }
        SettingsToggle(
          LocalizedStringResource("Enable Discord Rich Presence", bundle: #bundle, comment: "Settings toggle"),
          subtitle: LocalizedStringResource("Show your current ILoveMusic station and song in your Discord profile.", bundle: #bundle, comment: "Discord Rich Presence explanation"),
          isOn: $appModel.discordEnabled
        )
        if case .error(let message) = appModel.discordManager.state {
          Label {
            Text(verbatim: message)
          } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
          }
            .font(.callout)
            .foregroundStyle(.red)
        }
      } header: {
        Text("Connection", bundle: #bundle)
      }

      Section {
        SettingsToggle(
          LocalizedStringResource("Include current song artwork", bundle: #bundle, comment: "Settings toggle"),
          subtitle: LocalizedStringResource("Send the cover image of the song currently playing.", bundle: #bundle, comment: "Discord artwork setting explanation"),
          isOn: $appModel.discordShowArtwork
        )
        SettingsToggle(
          LocalizedStringResource("Include Listen button", bundle: #bundle, comment: "Settings toggle"),
          subtitle: LocalizedStringResource("Add a button to your profile that opens the station on ilovemusic.de.", bundle: #bundle, comment: "Discord Listen button explanation"),
          isOn: $appModel.discordShowButton
        )
        SettingsToggle(
          LocalizedStringResource("Include current listeners", bundle: #bundle, comment: "Settings toggle"),
          subtitle: LocalizedStringResource("Show the station's live listener count next to the channel name.", bundle: #bundle, comment: "Discord listener count explanation"),
          isOn: $appModel.discordShowListeners
        )
        SettingsToggle(
          LocalizedStringResource("Show station logo badge", bundle: #bundle, comment: "Settings toggle"),
          subtitle: LocalizedStringResource("Display the I Love Radio logo as the small artwork badge.", bundle: #bundle, comment: "Discord station badge explanation"),
          isOn: $appModel.discordShowStationLogo
        )
        LabeledContent {
          TextField(
            text: $appModel.discordClientID,
            prompt: Text(verbatim: "e.g. 1234567890123456789")
          ) {
            Text("Application ID", bundle: #bundle)
          }
          .textFieldStyle(.roundedBorder)
          .labelsHidden()
          .disableAutocorrection(true)
          .frame(minWidth: 220)
        } label: {
          Text("Application ID", bundle: #bundle)
        }
      } header: {
        Text("Rich Presence", bundle: #bundle)
      } footer: {
        Text("Create an application at developer.discord.com, then copy its Application ID here.", bundle: #bundle)
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
