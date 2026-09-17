import SwiftUI

struct StatsView: View {
  let appModel: AppModel
  let window: HistoryWindow

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      let snapshot = appModel.statsSnapshot(for: window, now: context.date)

      GeometryReader { proxy in
        let contentWidth = min(proxy.size.width - 48, StatsLayout.maximumContentWidth)

        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            if StatsLayout.showsPageEmptyState(eventCountInWindow: snapshot.eventCountInWindow) {
              StatsPageEmptyState(window: window)
            } else {
              StatsSummaryStrip(snapshot: snapshot)
              primaryTrend(snapshot: snapshot)
              supportingBreakdowns(snapshot: snapshot, width: contentWidth)
              listeningPatterns(snapshot: snapshot, width: contentWidth)
              rankings(snapshot: snapshot, width: contentWidth)
            }
          }
          .frame(width: max(0, contentWidth), alignment: .topLeading)
          .padding(.vertical, 24)
          .frame(maxWidth: .infinity)
        }
      }
    }
  }

  private func primaryTrend(snapshot: StatsSnapshot) -> some View {
    StatsSection(
      title: "Listening Trend",
      subtitle: "Listening time across the selected period"
    ) {
      ListeningTrendChart(
        dailyBuckets: snapshot.dailyTrend,
        hourBuckets: snapshot.hourOfDayBuckets,
        window: window
      )
    }
  }

  private func supportingBreakdowns(snapshot: StatsSnapshot, width: CGFloat) -> some View {
    LazyVGrid(columns: columns(for: width), spacing: 18) {
      StatsSection(title: "Top Channels") {
        TopChannelsChart(channels: Array(snapshot.topChannels.prefix(8)))
      }
      StatsSection(title: "Genres") {
        GenreDonutChart(shares: snapshot.genreShares)
      }
    }
  }

  private func listeningPatterns(snapshot: StatsSnapshot, width: CGFloat) -> some View {
    LazyVGrid(columns: columns(for: width), spacing: 18) {
      StatsSection(title: "Listening by Hour") {
        HourOfDayChart(secondsPerHour: snapshot.hourOfDayBuckets)
      }
      StatsSection(title: "Weekday and Hour") {
        WeekdayHourHeatmap(matrix: snapshot.weekdayHourHeatmap)
      }
    }
  }

  private func rankings(snapshot: StatsSnapshot, width: CGFloat) -> some View {
    let limit = StatsLayout.rankingLimit(for: width)

    return LazyVGrid(columns: columns(for: width), spacing: 18) {
      StatsSection(title: "Top Artists") {
        TopArtistsCard(artists: Array(snapshot.topArtists.prefix(limit)))
      }
      StatsSection(title: "Top Songs") {
        TopSongsCard(songs: Array(snapshot.topSongs.prefix(limit)))
      }
    }
  }

  private func columns(for width: CGFloat) -> [GridItem] {
    Array(
      repeating: GridItem(.flexible(), spacing: 18, alignment: .top),
      count: StatsLayout.supportingColumns(for: width)
    )
  }
}

private struct StatsPageEmptyState: View {
  let window: HistoryWindow

  @Environment(\.locale) private var locale

  var body: some View {
    ContentUnavailableView {
      Label {
        Text("No listening in this period", bundle: #bundle)
      } icon: {
        Image(systemName: "chart.bar.xaxis")
      }
    } description: {
      Text("Choose a broader time range or start listening to see your activity here.", bundle: #bundle)
    }
    .frame(maxWidth: .infinity, minHeight: 360)
    .accessibilityHint(
      Text(
        LocalizedStringResource(
          "The selected time range is \(String(localized: window.titleResource.resolved(in: locale))).",
          locale: locale,
          bundle: #bundle,
          comment: "Accessibility hint for an empty listening statistics range."
        )
      )
    )
  }
}
