import SwiftUI

struct TopArtistsCard: View {
  let artists: [ArtistTotal]

  @Environment(\.locale) private var locale

  var body: some View {
    if artists.isEmpty {
      StatsEmptyState(title: "No artists yet", subtitle: "Your most-played artists will land here.")
    } else {
      VStack(spacing: 0) {
        let topValue = artists.first?.listenedSeconds ?? 1
        ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
          VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Text(verbatim: "\(index + 1).")
                .font(.caption2.bold().monospacedDigit())
                .foregroundStyle(.tertiary)
              Text(verbatim: artist.artist)
                .font(.caption.bold())
                .lineLimit(1)
              Spacer()
              Text(
                verbatim: "\(formatShortListeningDuration(artist.listenedSeconds, locale: locale)) · \(localizedPlayCount(artist.playCount, locale: locale))"
              )
                .font(.caption2.monospacedDigit())
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
            .frame(height: 4)
          }
          .padding(.vertical, 7)

          if index < artists.count - 1 {
            Divider()
          }
        }
      }
    }
  }
}
