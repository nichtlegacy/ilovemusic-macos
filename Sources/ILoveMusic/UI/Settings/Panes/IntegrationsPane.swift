import SwiftUI

/// Combined Discord + Stream Deck integrations pane (native Form).
struct IntegrationsPane: View {
  @Bindable var appModel: AppModel

  var body: some View {
    Form {
      Section {
        LabeledContent("Status") {
          SettingsStatusDot(color: discordDot, label: appModel.discordManager.state.label)
        }
        SettingsToggle(
          "Enable Discord Rich Presence",
          subtitle: "Show your current ILoveMusic station and song in your Discord profile.",
          isOn: $appModel.discordEnabled
        )
        SettingsToggle(
          "Include current song artwork",
          subtitle: "Send the cover image of the song currently playing.",
          isOn: $appModel.discordShowArtwork
        )
        .opacity(appModel.discordEnabled ? 1 : 0.5)
        .disabled(!appModel.discordEnabled)
        SettingsToggle(
          "Include Listen button",
          subtitle: "Adds a button to your profile linking directly to the station on ilovemusic.de.",
          isOn: $appModel.discordShowButton
        )
        .opacity(appModel.discordEnabled ? 1 : 0.5)
        .disabled(!appModel.discordEnabled)
        SettingsToggle(
          "Include current listeners",
          subtitle: "Shows the station's live listener count next to the channel name in Discord.",
          isOn: $appModel.discordShowListeners
        )
        .opacity(appModel.discordEnabled ? 1 : 0.5)
        .disabled(!appModel.discordEnabled)
        SettingsToggle(
          "Show station logo badge",
          subtitle: "Displays the I Love Radio logo as the small badge on the Discord artwork.",
          isOn: $appModel.discordShowStationLogo
        )
        .opacity(appModel.discordEnabled ? 1 : 0.5)
        .disabled(!appModel.discordEnabled)
        VStack(alignment: .leading, spacing: 6) {
          Text("Application ID")
          TextField(
            "Application ID",
            text: $appModel.discordClientID,
            prompt: Text("e.g. 1234567890123456789")
          )
          .textFieldStyle(.roundedBorder)
          .disableAutocorrection(true)
          .frame(maxWidth: .infinity)
        }
        if case .error(let message) = appModel.discordManager.state {
          Label(message, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
            .font(.callout)
        }
      } header: {
        Text("Discord")
      } footer: {
        Text("Create an application at developer.discord.com → Applications → New Application, then copy the Application ID here.")
      }

      SettingsDisclosureGroup("Discord connection log") {
        LogPanel(
          entries: appModel.discordConnectionLog,
          persistedCap: 80,
          displayLimit: 10,
          onClear: { appModel.clearDiscordConnectionLog() }
        )
      }

      Section {
        LabeledContent("Status") {
          SettingsStatusDot(color: streamDeckDot, label: streamDeckLabel)
        }
        LabeledContent("Server model", value: "Local HTTP bridge")
        LabeledContent("Handshake", value: handshakeEntry?.timestamp.shortTimeOrDateTime ?? "Not written yet")
        LabeledContent("Last request", value: lastRequestAt?.shortTimeOrDateTime ?? "No request yet")
        LabeledContent("Last issue", value: issueEntry?.message ?? "None")
      } header: {
        Text("Stream Deck")
      } footer: {
        Text("The app does not keep a permanent Stream Deck socket open. It publishes a local control.json, and the plugin reads that file and calls the local HTTP endpoints again after a disconnect or app restart.")
      }

      SettingsDisclosureGroup("Stream Deck connection log") {
        LogPanel(
          entries: appModel.controlConnectionLog,
          persistedCap: 80,
          displayLimit: 10,
          onClear: { appModel.clearControlConnectionLog() }
        )
      }
    }
    .settingsFormStyle()
  }

  // MARK: - Discord status

  private var discordDot: Color {
    switch appModel.discordManager.state {
    case .connected: return .green
    case .connecting: return .orange
    case .error: return .red
    case .disconnected: return .secondary
    }
  }

  // MARK: - Stream Deck status

  private var lastRequestAt: Date? {
    appModel.controlRuntimeStatus.lastRequestAt
  }

  private var handshakeEntry: ControlLogEntry? {
    appModel.controlConnectionLog.last(where: { $0.area == "Handshake" })
  }

  private var issueEntry: ControlLogEntry? {
    appModel.controlConnectionLog.last(where: { $0.severity != .info })
  }

  private var hasRecentRequest: Bool {
    guard let lastRequestAt else { return false }
    return Date().timeIntervalSince(lastRequestAt) < 300
  }

  private var hasError: Bool {
    appModel.controlConnectionLog.contains(where: { $0.severity == .error })
  }

  private var streamDeckLabel: String {
    if hasError { return "Issue" }
    if hasRecentRequest { return "Receiving Requests" }
    if lastRequestAt != nil { return "Idle" }
    return "Waiting for Plugin"
  }

  private var streamDeckDot: Color {
    if hasError { return .red }
    if hasRecentRequest { return .green }
    if lastRequestAt != nil { return .secondary }
    return .orange
  }
}
