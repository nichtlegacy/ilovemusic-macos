import SwiftUI

struct StreamDeckPane: View {
  @Environment(\.locale) private var locale
  @Bindable var appModel: AppModel

  var body: some View {
    Form {
      Section {
        LabeledContent {
          SettingsStatusDot(color: statusColor, label: statusLabel)
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

  private var statusLabel: String {
    String(localized: statusResource.resolved(in: locale))
  }

  private var statusResource: LocalizedStringResource {
    if hasError { return LocalizedStringResource("Issue", bundle: #bundle, comment: "Stream Deck bridge status") }
    if hasRecentRequest { return LocalizedStringResource("Receiving Requests", bundle: #bundle, comment: "Stream Deck bridge status") }
    if lastRequestAt != nil { return LocalizedStringResource("Idle", bundle: #bundle, comment: "Stream Deck bridge status") }
    return LocalizedStringResource("Waiting for Plugin", bundle: #bundle, comment: "Stream Deck bridge status")
  }

  private var statusColor: Color {
    if hasError { return .red }
    if hasRecentRequest { return .green }
    if lastRequestAt != nil { return .secondary }
    return .orange
  }
}
