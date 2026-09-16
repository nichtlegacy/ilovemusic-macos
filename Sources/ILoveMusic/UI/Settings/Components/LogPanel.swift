import SwiftUI

/// Severity filter shown above the rolling log.
enum LogSeverityFilter: String, CaseIterable, Identifiable, Hashable {
  case all
  case info
  case warning
  case error

  var id: String { rawValue }
  var title: String {
    switch self {
    case .all: "All"
    case .info: "Info"
    case .warning: "Warning"
    case .error: "Error"
    }
  }

  func matches(_ entry: ControlLogEntry) -> Bool {
    switch self {
    case .all: return true
    case .info: return entry.severity == .info
    case .warning: return entry.severity == .warning
    case .error: return entry.severity == .error
    }
  }
}

/// Drop-in log list for the Integrations pane.
///
/// No inner ScrollView: the surrounding Form already scrolls. Shows the tail
/// of the rolling diagnostic log (newest first) with severity filter + Clear.
@MainActor
struct LogPanel: View {
  let entries: [ControlLogEntry]
  /// Persistence cap. Shown in the footer ("auto-pruned after N") so the user
  /// understands why old entries disappear.
  let persistedCap: Int
  let onClear: () -> Void
  /// Max number of entries to render.
  let displayLimit: Int

  @State private var severity: LogSeverityFilter = .all

  init(
    entries: [ControlLogEntry],
    persistedCap: Int,
    displayLimit: Int = 10,
    onClear: @escaping () -> Void
  ) {
    self.entries = entries
    self.persistedCap = persistedCap
    self.displayLimit = displayLimit
    self.onClear = onClear
  }

  private var filteredEntries: [ControlLogEntry] {
    let matching = entries.filter { severity.matches($0) }
    return Array(matching.suffix(displayLimit).reversed())
  }

  var body: some View {
    HStack {
      Picker("Severity", selection: $severity) {
        ForEach(LogSeverityFilter.allCases) { filter in
          Text(filter.title).tag(filter)
        }
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .frame(maxWidth: 110)
      Spacer()
      Button("Clear") { onClear() }
        .disabled(entries.isEmpty)
    }
    if filteredEntries.isEmpty {
      Text(entries.isEmpty ? "No events yet." : "No entries match this filter.")
        .font(.footnote)
        .foregroundStyle(.tertiary)
    } else {
      VStack(alignment: .leading, spacing: 8) {
        ForEach(filteredEntries) { entry in
          LogPanelRow(entry: entry)
        }
      }
      Text("Showing last \(min(displayLimit, max(entries.count, 0))) entries · auto-pruned after \(persistedCap)")
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
  }
}

/// Individual rolling-log row.
@MainActor
struct LogPanelRow: View {
  let entry: ControlLogEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(entry.timestamp.shortTimeOrDateTime)
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
        Text(entry.area)
          .font(.caption.weight(.semibold))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(.quaternary, in: Capsule())
        Spacer()
        Circle()
          .fill(severityColor)
          .frame(width: 7, height: 7)
          .accessibilityLabel(severityLabel)
      }
      Text(entry.message)
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
  }

  private var severityColor: Color {
    switch entry.severity {
    case .info: return .green
    case .warning: return .orange
    case .error: return .red
    }
  }

  private var severityLabel: String {
    switch entry.severity {
    case .info: return "Info"
    case .warning: return "Warning"
    case .error: return "Error"
    }
  }
}
