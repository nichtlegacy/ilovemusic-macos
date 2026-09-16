import SwiftUI

struct StatsView: View {
  let appModel: AppModel
  let window: HistoryWindow

  var body: some View {
    let snapshot = appModel.statsSnapshot(for: window)

    ScrollView {
      VStack(spacing: 16) {
        StatCardsRow(snapshot: snapshot)

        Grid(horizontalSpacing: 16, verticalSpacing: 16) {
          GridRow {
            StatsCard(title: "Top Channels") {
              TopChannelsChart(channels: Array(snapshot.topChannels.prefix(10)))
            }
            StatsCard(title: "Genre-Verteilung") {
              GenreDonutChart(shares: snapshot.genreShares)
            }
          }

          GridRow {
            StatsCard(title: "Listening Trend", fullWidth: true) {
              ListeningTrendChart(
                dailyBuckets: snapshot.dailyTrend,
                hourBuckets: snapshot.hourOfDayBuckets,
                window: window
              )
            }
            .gridCellColumns(2)
          }

          GridRow {
            StatsCard(title: "24-Stunden-Verteilung") {
              HourOfDayChart(secondsPerHour: snapshot.hourOfDayBuckets)
            }
            StatsCard(title: "Wochentag × Stunde") {
              WeekdayHourHeatmap(matrix: snapshot.weekdayHourHeatmap)
            }
          }

          GridRow {
            StatsCard(title: "Top Artists") {
              TopArtistsCard(artists: Array(snapshot.topArtists.prefix(10)))
            }
            StatsCard(title: "Top Songs") {
              TopSongsCard(songs: Array(snapshot.topSongs.prefix(10)))
            }
          }
        }

        if snapshot.averageSessionSeconds > 0 {
          HStack {
            Spacer()
            Text("Durchschnittliche Session: \(formatShortListeningDuration(snapshot.averageSessionSeconds))")
              .font(.system(size: 12, weight: .medium).monospacedDigit())
              .foregroundStyle(.secondary)
          }
          .padding(.horizontal, 4)
        }
      }
      .padding(20)
    }
  }
}
