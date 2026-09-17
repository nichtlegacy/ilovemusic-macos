import SwiftUI

/// Severity filter shown above the rolling log.
enum LogSeverityFilter: String, CaseIterable, Identifiable, Hashable {
  case all
  case info
  case warning
  case error

  var id: String { rawValue }
  var titleResource: LocalizedStringResource {
    switch self {
    case .all: LocalizedStringResource("All", bundle: #bundle, comment: "Log severity filter")
    case .info: LocalizedStringResource("Info", bundle: #bundle, comment: "Log severity filter")
    case .warning: LocalizedStringResource("Warning", bundle: #bundle, comment: "Log severity filter")
    case .error: LocalizedStringResource("Error", bundle: #bundle, comment: "Log severity filter")
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
  @Environment(\.locale) private var locale
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
      Picker(selection: $severity) {
        ForEach(LogSeverityFilter.allCases) { filter in
          Text(filter.titleResource.resolved(in: locale)).tag(filter)
        }
      } label: {
        Text("Severity", bundle: #bundle)
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .frame(maxWidth: 110)
      Spacer()
      Button { onClear() } label: { Text("Clear", bundle: #bundle) }
        .disabled(entries.isEmpty)
    }
    if filteredEntries.isEmpty {
      (entries.isEmpty
        ? Text("No events yet.", bundle: #bundle)
        : Text("No entries match this filter.", bundle: #bundle))
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
      Text("Showing \(filteredEntries.count) of \(matchingEntryCount) matching entries · stores up to \(persistedCap)", bundle: #bundle)
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
  }
}

/// Individual rolling-log row.
@MainActor
struct LogPanelRow: View {
  @Environment(\.locale) private var locale
  let entry: ControlLogEntry

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(verbatim: entry.timestamp.shortTimeOrDateTime(locale: locale))
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 104, alignment: .leading)
      Text(verbatim: entry.area)
        .font(.caption.weight(.semibold))
        .frame(width: 82, alignment: .leading)
        .lineLimit(1)
      Circle()
        .fill(severityColor)
        .frame(width: 7, height: 7)
        .accessibilityLabel(Text(severityResource.resolved(in: locale)))
      Text(verbatim: entry.message)
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

  private var severityResource: LocalizedStringResource {
    switch entry.severity {
    case .info: return LocalizedStringResource("Info", bundle: #bundle, comment: "Accessible log severity")
    case .warning: return LocalizedStringResource("Warning", bundle: #bundle, comment: "Accessible log severity")
    case .error: return LocalizedStringResource("Error", bundle: #bundle, comment: "Accessible log severity")
    }
  }
}
