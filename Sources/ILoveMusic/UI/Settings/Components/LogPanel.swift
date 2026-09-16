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

/// Drop-in log panel for the Discord and Stream Deck panes.
///
/// Displays the tail of a rolling diagnostic log (newest first), with a
/// severity filter and Clear button. Persistence caps stay where they are
/// in `ControlDiagnosticsStore` / `DiscordDiagnosticsStore` — this view only
/// limits the visible window.
@MainActor
struct LogPanel: View {
  let title: String
  let entries: [ControlLogEntry]
  /// Persistence cap. Shown in the footer ("auto-pruned after N") so the user
  /// understands why old entries disappear.
  let persistedCap: Int
  let onClear: () -> Void
  /// Max number of entries to render.
  let displayLimit: Int

  @State private var severity: LogSeverityFilter = .all

  init(
    title: String = "Connection Log",
    entries: [ControlLogEntry],
    persistedCap: Int,
    displayLimit: Int = 20,
    onClear: @escaping () -> Void
  ) {
    self.title = title
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
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center) {
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
        Spacer()
        Picker("Severity", selection: $severity) {
          ForEach(LogSeverityFilter.allCases) { filter in
            Text(filter.title).tag(filter)
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(maxWidth: 110)
        Button("Clear") { onClear() }
          .disabled(entries.isEmpty)
      }

      Group {
        if filteredEntries.isEmpty {
          Text(entries.isEmpty ? "No events yet." : "No entries match this filter.")
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 24)
        } else {
          ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 10) {
              ForEach(filteredEntries) { entry in
                LogPanelRow(entry: entry)
              }
            }
            .padding(.bottom, 2)
          }
          .frame(height: 260)
        }
      }

      Text("Showing last \(min(displayLimit, max(entries.count, 0))) entries · auto-pruned after \(persistedCap)")
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
  }
}

/// Individual rolling-log row. Layout & tokens come from `design.md` §5.5.
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
    case .warning: return .yellow
    case .error: return .red
    }
  }
}
