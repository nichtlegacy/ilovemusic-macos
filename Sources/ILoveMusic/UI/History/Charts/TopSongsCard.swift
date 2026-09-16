import SwiftUI

struct TopSongsCard: View {
  let songs: [SongTotal]

  var body: some View {
    if songs.isEmpty {
      StatsEmptyState(title: "No songs yet", subtitle: "Once you've built up some history, your most-played tracks will appear here.")
    } else {
      VStack(spacing: 10) {
        ForEach(songs) { song in
          HStack(spacing: 10) {
            ArtworkView(
              station: nil,
              currentSongArtworkURL: song.artworkURLString.flatMap(URL.init(string:)),
              size: 32,
              cornerRadius: 8
            )

            VStack(alignment: .leading, spacing: 3) {
              Text(song.title.isEmpty ? "Unknown song" : song.title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
              Text(song.artist.isEmpty ? "Unknown artist" : song.artist)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
              Text(formatShortListeningDuration(song.listenedSeconds))
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
              Text("\(song.playCount) plays")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.tertiary)
            }
          }
        }
      }
    }
  }
}
