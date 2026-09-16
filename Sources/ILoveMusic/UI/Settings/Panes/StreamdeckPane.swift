import SwiftUI

struct StreamdeckPane: View {
  let appModel: AppModel

  var body: some View {
    PrefsScrollPane {
      PaneHeaderCard(
        systemImage: "rectangle.3.group.bubble.left.fill",
        iconColor: .orange,
        title: "Stream Deck",
        subtitle: "Local control bridge",
        badgeColor: badgeColor,
        badgeLabel: badgeLabel
      )

      Divider()

      SettingsBlock("Status") {
        DataRow(label: "Server model", value: "Local HTTP bridge")
        DataRow(label: "Reconnect model", value: "Plugin sends fresh requests")
        DataRow(label: "Handshake updated", value: handshakeEntry?.timestamp.shortTimeOrDateTime ?? "Not written yet")
        DataRow(label: "Last request", value: lastRequestAt?.shortTimeOrDateTime ?? "No request yet")
        DataRow(label: "Last issue", value: issueEntry?.message ?? "None")
        Text("The app does not keep a permanent Stream Deck socket open. It publishes a local `control.json`, and the plugin must read that file and call the local HTTP endpoints again after a disconnect or app restart.")
          .font(.footnote)
          .foregroundStyle(.tertiary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Divider()

      LogPanel(
        title: "Connection Log",
        entries: appModel.controlConnectionLog,
        persistedCap: 80,
        displayLimit: 20,
        onClear: { appModel.clearControlConnectionLog() }
      )
    }
  }

  // MARK: - Status helpers

  // Routine reads no longer hit the persistent log (P2). Plugin activity is
  // mirrored to `appModel.controlRuntimeStatus`; the log only carries
  // mutations, handshake updates, and errors.

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

  private var badgeLabel: String {
    if hasError { return "Issue" }
    if hasRecentRequest { return "Receiving Requests" }
    if lastRequestAt != nil { return "Idle" }
    return "Waiting for Plugin"
  }

  private var badgeColor: Color {
    if hasError { return .red }
    if hasRecentRequest { return .green }
    if lastRequestAt != nil { return .secondary }
    return .yellow
  }
}
