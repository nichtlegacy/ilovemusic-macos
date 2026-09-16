import SwiftUI

struct TopSongsCard: View {
  let songs: [SongTotal]

  var body: some View {
    if songs.isEmpty {
      StatsEmptyState(title: "No songs yet", subtitle: "Once you've built up some history, your most-played tracks will appear here.")
    } else {
      VStack(spacing: 0) {
        ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
          HStack(spacing: 10) {
            ArtworkView(
              station: nil,
              currentSongArtworkURL: song.artworkURLString.flatMap(URL.init(string:)),
              size: 28,
              cornerRadius: 7
            )

            VStack(alignment: .leading, spacing: 3) {
              Text(song.title.isEmpty ? "Unknown song" : song.title)
                .font(.caption.bold())
                .lineLimit(1)
              Text(song.artist.isEmpty ? "Unknown artist" : song.artist)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
              Text(formatShortListeningDuration(song.listenedSeconds))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
              Text("\(song.playCount) plays")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
            }
          }
          .padding(.vertical, 6)

          if index < songs.count - 1 {
            Divider()
          }
        }
      }
    }
  }
}
