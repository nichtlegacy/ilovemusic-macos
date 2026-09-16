import SwiftUI

struct DiscordPane: View {
  @Bindable var appModel: AppModel

  var body: some View {
    PrefsScrollPane {
      PaneHeaderCard(
        systemImage: "gamecontroller.fill",
        iconColor: Color(red: 0.345, green: 0.396, blue: 0.949),
        iconFontSize: 26,
        title: "Discord",
        subtitle: "Rich Presence integration",
        badgeColor: badgeColor,
        badgeLabel: appModel.discordManager.state.label
      )

      Divider()

      SettingsBlock("Rich Presence") {
        let enabled = appModel.discordEnabled
        PreferenceToggleRow(
          title: "Enable Discord Rich Presence",
          subtitle: "Show your current ILoveMusic station and song in your Discord profile.",
          isOn: $appModel.discordEnabled
        )
        PreferenceToggleRow(
          title: "Include current song artwork",
          subtitle: "Send the cover image of the song currently playing.",
          isOn: $appModel.discordShowArtwork
        )
        .opacity(enabled ? 1 : 0.5)
        .disabled(!enabled)

        PreferenceToggleRow(
          title: "Include Listen button",
          subtitle: "Adds a button to your profile linking directly to the station on ilovemusic.de.",
          isOn: $appModel.discordShowButton
        )
        .opacity(enabled ? 1 : 0.5)
        .disabled(!enabled)

        PreferenceToggleRow(
          title: "Include current listeners",
          subtitle: "Shows the station's live listener count next to the channel name in Discord.",
          isOn: $appModel.discordShowListeners
        )
        .opacity(enabled ? 1 : 0.5)
        .disabled(!enabled)

        PreferenceToggleRow(
          title: "Show station logo badge",
          subtitle: "Displays the I Love Radio logo as the small badge on the Discord artwork.",
          isOn: $appModel.discordShowStationLogo
        )
        .opacity(enabled ? 1 : 0.5)
        .disabled(!enabled)
      }

      Divider()

      SettingsBlock("Application") {
        VStack(alignment: .leading, spacing: 6) {
          Text("Application ID").font(.body)
          Text("Create an application at developer.discord.com → Applications → New Application, then copy the Application ID here.")
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
          TextField(
            "Application ID",
            text: $appModel.discordClientID,
            prompt: Text("e.g. 1234567890123456789")
          )
          .textFieldStyle(.roundedBorder)
          .disableAutocorrection(true)
          .textContentType(nil)
        }
      }

      Divider()

      LogPanel(
        title: "Connection Log",
        entries: appModel.discordConnectionLog,
        persistedCap: 80,
        displayLimit: 20,
        onClear: { appModel.clearDiscordConnectionLog() }
      )

      if case .error(let message) = appModel.discordManager.state {
        Divider()
        Label(message, systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(.red)
          .font(.callout)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private var badgeColor: Color {
    switch appModel.discordManager.state {
    case .connected: return .green
    case .connecting: return .yellow
    case .error: return .red
    case .disconnected: return .secondary
    }
  }
}
