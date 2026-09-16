import SwiftUI

struct TopArtistsCard: View {
  let artists: [ArtistTotal]

  var body: some View {
    if artists.isEmpty {
      StatsEmptyState(title: "No artists yet", subtitle: "Your most-played artists will land here.")
    } else {
      VStack(spacing: 10) {
        let topValue = artists.first?.listenedSeconds ?? 1
        ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
          VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Text("\(index + 1).")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.tertiary)
              Text(artist.artist)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
              Spacer()
              Text("\(formatShortListeningDuration(artist.listenedSeconds)) · \(artist.playCount) plays")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
              Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .overlay(alignment: .leading) {
                  Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.75))
                    .frame(width: max(10, proxy.size.width * CGFloat(artist.listenedSeconds / topValue)))
                }
            }
            .frame(height: 6)
          }
        }
      }
    }
  }
}
