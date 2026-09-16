import SwiftUI

struct StreamDeckPane: View {
  @Bindable var appModel: AppModel

  var body: some View {
    Form {
      Section {
        LabeledContent("Status") {
          SettingsStatusDot(color: statusColor, label: statusLabel)
        }
        LabeledContent("Bridge", value: "Local HTTP")
        LabeledContent("Handshake", value: handshakeEntry?.timestamp.shortTimeOrDateTime ?? "Not written yet")
        LabeledContent("Last request", value: lastRequestAt?.shortTimeOrDateTime ?? "No request yet")
        LabeledContent("Last issue", value: issueEntry?.message ?? "None")
      } header: {
        Text("Status")
      } footer: {
        Text("The plugin reads the local control file and calls ILoveMusic's HTTP bridge. It reconnects automatically after the app or plugin restarts.")
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
    if hasError { return "Issue" }
    if hasRecentRequest { return "Receiving Requests" }
    if lastRequestAt != nil { return "Idle" }
    return "Waiting for Plugin"
  }

  private var statusColor: Color {
    if hasError { return .red }
    if hasRecentRequest { return .green }
    if lastRequestAt != nil { return .secondary }
    return .orange
  }
}
