import AppKit
import SwiftUI

private enum StationFilter: Hashable {
  case all
  case station(String)
}

private struct HistoryDayGroup: Identifiable {
  let date: Date
  let totalSeconds: Double
  let events: [PlayEvent]

  var id: Date { date }
}

struct HistoryListView: View {
  let appModel: AppModel

  @State private var query = ""
  @State private var stationFilter: StationFilter = .all
  @Environment(\.locale) private var locale

  private var recorder: PlayHistoryRecorder { appModel.historyRecorder }

  var body: some View {
    // Compute the filtered/sorted pipeline once per render and thread the
    // results into the subviews. Previously `filteredEvents` was evaluated
    // twice per body pass (once for the header count, once via `groupedDays`),
    // re-running three filters plus a sort over the entire history on every
    // observable update while the window is open.
    let events = filteredEvents
    let days = groupedDays(from: events)

    return VStack(spacing: 0) {
      filterBar(matchCount: events.count)
      Divider()
      content(days: days)
    }
    .searchable(
      text: $query,
      placement: .toolbar,
      prompt: Text("Songs, artists, or channels", bundle: #bundle)
    )
  }

  private func filterBar(matchCount: Int) -> some View {
    HStack(spacing: 10) {
      Picker(selection: $stationFilter) {
        Text("All Channels", bundle: #bundle).tag(StationFilter.all)
        ForEach(stationsForMenu, id: \.stationID) { station in
          Text(verbatim: station.stationName).tag(StationFilter.station(station.stationID))
        }
      } label: {
        Text("Channel", bundle: #bundle)
      }
      .pickerStyle(.menu)
      .frame(maxWidth: 220)

      Spacer()

      Text(verbatim: localizedSongCount(matchCount, locale: locale))
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }

  @ViewBuilder
  private func content(days: [HistoryDayGroup]) -> some View {
    if recorder.events.isEmpty {
      HistoryEmptyState(
        icon: "clock.arrow.circlepath",
        title: LocalizedStringResource("No history yet", bundle: #bundle),
        subtitle: appModel.preferences.recordHistoryEnabled == false
          ? LocalizedStringResource("History recording is disabled in Settings.", bundle: #bundle)
          : LocalizedStringResource("Once you listen to a channel for at least 10 seconds, it shows up here.", bundle: #bundle),
        openSettings: appModel.preferences.recordHistoryEnabled == false
          ? { appModel.requestOpenSettingsWindow?() }
          : nil
      )
    } else if days.isEmpty {
      HistoryEmptyState(
        icon: "line.3.horizontal.decrease.circle",
        title: LocalizedStringResource("No matches for this selection", bundle: #bundle),
        subtitle: LocalizedStringResource("Adjust the search or channel filter.", bundle: #bundle),
        buttonTitle: LocalizedStringResource("Reset filters", bundle: #bundle),
        action: {
          query = ""
          stationFilter = .all
        }
      )
    } else {
      List {
        ForEach(days) { day in
          Section {
            ForEach(day.events) { event in
              HistoryRow(
                event: event,
                station: appModel.stations.first(where: { $0.id == event.stationID }),
                accent: Color(hex: appModel.stations.first(where: { $0.id == event.stationID })?.accentHex ?? event.stationAccentHex),
                onCopy: {
                  let parts = [event.artist, event.title].filter { !$0.isEmpty }
                  NSPasteboard.general.clearContents()
                  NSPasteboard.general.setString(parts.joined(separator: " – "), forType: .string)
                },
                onFilterStation: {
                  stationFilter = .station(event.stationID)
                  query = ""
                }
              )
            }
          } header: {
            HistoryDayHeader(
              date: day.date,
              totalSeconds: day.totalSeconds,
              eventCount: day.events.count
            )
          }
        }
      }
      .listStyle(.inset)
      .scrollContentBackground(.hidden)
    }
  }

  private var filteredEvents: [PlayEvent] {
    recorder.events
      .filter { $0.endedAt != nil }
      .filter { event in
        switch stationFilter {
        case .all:
          return true
        case .station(let stationID):
          return event.stationID == stationID
        }
      }
      .filter { event in
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let haystack = [event.artist, event.title, event.stationName]
          .joined(separator: " ")
        return haystack.localizedStandardContains(needle)
      }
      .sorted {
        if $0.startedAt != $1.startedAt {
          return $0.startedAt > $1.startedAt
        }
        return $0.id.uuidString > $1.id.uuidString
      }
  }

  private func groupedDays(from events: [PlayEvent]) -> [HistoryDayGroup] {
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: events) { event in
      calendar.startOfDay(for: event.startedAt)
    }

    return grouped.keys.sorted(by: >).map { date in
      let events = grouped[date] ?? []
      let total = events.reduce(0) { $0 + ($1.listenedSeconds ?? 0) }
      return HistoryDayGroup(date: date, totalSeconds: total, events: events)
    }
  }

  private var stationsForMenu: [(stationID: String, stationName: String)] {
    let latestByStation = Dictionary(
      filteredKeysFromEvents.map { ($0.stationID, $0.stationName) },
      uniquingKeysWith: { left, _ in left }
    )

    return latestByStation
      .map { (stationID: $0.key, stationName: $0.value) }
      .sorted {
        $0.stationName.localizedCaseInsensitiveCompare($1.stationName) == .orderedAscending
      }
  }

  private var filteredKeysFromEvents: [PlayEvent] {
    recorder.events.filter { $0.endedAt != nil }
  }

}

private struct HistoryDayHeader: View {
  let date: Date
  let totalSeconds: Double
  let eventCount: Int

  @Environment(\.locale) private var locale

  var body: some View {
    HStack {
      Group {
        if Calendar.current.isDateInToday(date) {
          Text("Today", bundle: #bundle)
        } else if Calendar.current.isDateInYesterday(date) {
          Text("Yesterday", bundle: #bundle)
        } else {
          Text(verbatim: date.formatted(
            Date.FormatStyle(
              date: .abbreviated,
              time: .omitted,
              locale: locale
            )
            .weekday(.abbreviated)
          ))
        }
      }
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(.secondary)
      Spacer()
      Text(
        verbatim: "\(formatShortListeningDuration(totalSeconds, locale: locale)) · \(localizedSongCount(eventCount, locale: locale))"
      )
        .font(.system(size: 11, weight: .medium).monospacedDigit())
        .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 4)
  }

}

private struct HistoryRow: View {
  let event: PlayEvent
  let station: Station?
  let accent: Color
  let onCopy: () -> Void
  let onFilterStation: () -> Void

  @Environment(\.locale) private var locale

  var body: some View {
    HStack(spacing: 12) {
      ArtworkView(
        station: station,
        currentSongArtworkURL: event.artworkURLString.flatMap(URL.init(string:)),
        size: 38,
        cornerRadius: 8
      )

      VStack(alignment: .leading, spacing: 4) {
        if trackLine.isEmpty {
          Text("Unknown Track", bundle: #bundle)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
        } else {
          Text(verbatim: trackLine)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)
        }

        Text(tintedStationName(event.stationName, accent: accent))
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 12)

      VStack(alignment: .trailing, spacing: 4) {
        Text(verbatim: event.startedAt.formatted(
          Date.FormatStyle(date: .omitted, time: .shortened, locale: locale)
        ))
          .font(.system(size: 12, weight: .medium).monospacedDigit())
          .foregroundStyle(.secondary)
        Text(formatClockDuration(event.listenedSeconds ?? 0))
          .font(.system(size: 11, weight: .medium).monospacedDigit())
          .foregroundStyle(.tertiary)
      }
    }
    .padding(.vertical, 6)
    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
    .listRowSeparator(.visible)
    .contextMenu {
      Button {
        onCopy()
      } label: {
        Text("Copy", bundle: #bundle)
      }

      Button {
        onFilterStation()
      } label: {
        Text("Filter by This Channel", bundle: #bundle)
      }
    }
  }

  private var trackLine: String {
    let parts = [event.artist, event.title].filter { !$0.isEmpty }
    return parts.joined(separator: " – ")
  }
}

private struct HistoryEmptyState: View {
  let icon: String
  let title: LocalizedStringResource
  let subtitle: LocalizedStringResource
  var openSettings: (() -> Void)? = nil
  var buttonTitle: LocalizedStringResource?
  var action: (() -> Void)?

  @Environment(\.locale) private var locale

  var body: some View {
    VStack(spacing: 12) {
      Spacer()
      Image(systemName: icon)
        .font(.system(size: 44, weight: .light))
        .foregroundStyle(.tertiary)
      Text(title.resolved(in: locale))
        .font(.system(size: 18, weight: .semibold))
      Text(subtitle.resolved(in: locale))
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 360)

      if let openSettings {
        Button(action: openSettings) {
          Text("Open Settings…", bundle: #bundle)
        }
      } else if let buttonTitle, let action {
        Button(action: action) {
          Text(buttonTitle.resolved(in: locale))
        }
      }

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private func formatClockDuration(_ seconds: Double) -> String {
  let totalSeconds = Int(seconds.rounded())
  let minutes = totalSeconds / 60
  let remainder = totalSeconds % 60
  return "\(minutes):" + String(format: "%02d", remainder)
}
