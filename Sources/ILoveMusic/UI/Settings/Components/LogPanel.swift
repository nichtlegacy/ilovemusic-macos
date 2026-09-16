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

/// Compact rolling log used by the Advanced pane.
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

  private var matchingEntryCount: Int {
    entries.count(where: { severity.matches($0) })
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
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
          LogPanelRow(entry: entry)
          if index < filteredEntries.count - 1 {
            Divider()
          }
        }
      }
      Text("Showing \(filteredEntries.count) of \(matchingEntryCount) matching entries · stores up to \(persistedCap)")
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
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(entry.timestamp.shortTimeOrDateTime)
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 104, alignment: .leading)
      Text(entry.area)
        .font(.caption.weight(.semibold))
        .frame(width: 82, alignment: .leading)
        .lineLimit(1)
      Circle()
        .fill(severityColor)
        .frame(width: 7, height: 7)
        .accessibilityLabel(severityLabel)
      Text(entry.message)
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.vertical, 6)
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
