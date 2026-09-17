import SwiftUI

struct StreamDeckPane: View {
  @Environment(\.locale) private var locale
  @Bindable var appModel: AppModel

  var body: some View {
    TimelineView(.periodic(from: .now, by: 30)) { context in
      let status = StreamDeckConnectionStatus.resolve(
        runtime: appModel.controlRuntimeStatus,
        now: context.date
      )

      Form {
        Section {
          LabeledContent {
            SettingsStatusDot(color: statusColor(status), label: statusLabel(status))
          } label: {
            Text("Status", bundle: #bundle)
          }
          LabeledContent { Text(verbatim: "Local HTTP") } label: { Text("Bridge", bundle: #bundle) }
          LabeledContent {
            if let date = handshakeEntry?.timestamp { Text(verbatim: date.shortTimeOrDateTime(locale: locale)) } else { Text("Not written yet", bundle: #bundle) }
          } label: { Text("Handshake", bundle: #bundle) }
          LabeledContent {
            if let lastRequestAt { Text(verbatim: lastRequestAt.shortTimeOrDateTime(locale: locale)) } else { Text("No request yet", bundle: #bundle) }
          } label: { Text("Last request", bundle: #bundle) }
          LabeledContent {
            if let message = issueEntry?.message { Text(verbatim: message) } else { Text("None", bundle: #bundle) }
          } label: { Text("Last issue", bundle: #bundle) }
        } header: {
          Text("Status", bundle: #bundle)
        } footer: {
          Text("The plugin reads the local control file and calls ILoveMusic's HTTP bridge. It reconnects automatically after the app or plugin restarts.", bundle: #bundle)
        }
      }
      .settingsFormStyle()
    }
  }

  private var lastRequestAt: Date? {
    appModel.controlRuntimeStatus.lastRequestAt
  }

  private var handshakeEntry: ControlLogEntry? {
    appModel.controlConnectionLog.last(where: { $0.area == "Handshake" })
  }

  private var issueEntry: ControlLogEntry? {
    appModel.controlConnectionLog.last(where: { $0.severity != .info })
  }

  private func statusLabel(_ status: StreamDeckConnectionStatus) -> String {
    String(localized: statusResource(status).resolved(in: locale))
  }

  private func statusResource(_ status: StreamDeckConnectionStatus) -> LocalizedStringResource {
    switch status {
    case .issue: LocalizedStringResource("Issue", bundle: #bundle, comment: "Stream Deck bridge status")
    case .receivingRequests: LocalizedStringResource("Receiving Requests", bundle: #bundle, comment: "Stream Deck bridge status")
    case .idle: LocalizedStringResource("Idle", bundle: #bundle, comment: "Stream Deck bridge status")
    case .waitingForPlugin: LocalizedStringResource("Waiting for Plugin", bundle: #bundle, comment: "Stream Deck bridge status")
    }
  }

  private func statusColor(_ status: StreamDeckConnectionStatus) -> Color {
    switch status {
    case .issue: .red
    case .receivingRequests: .green
    case .idle: .secondary
    case .waitingForPlugin: .orange
    }
  }
}
