import SwiftUI

struct ArtworkView: View {
  let station: Station?
  let currentSongArtworkURL: URL?
  let size: CGFloat
  var cornerRadius: CGFloat = 12

  var body: some View {
    Group {
      if let url = primaryArtworkURL {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image.resizable().scaledToFill()
          case .failure, .empty:
            fallback
          @unknown default:
            fallback
          }
        }
      } else {
        fallback
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
    )
  }

  private var primaryArtworkURL: URL? {
    if let currentSongArtworkURL { return currentSongArtworkURL }
    return station?.artworkURL
  }

  @ViewBuilder
  private var fallback: some View {
    if let station {
      let accent = Color(hex: station.accentHex)
      ZStack {
        LinearGradient(
          colors: [accent, accent.opacity(0.6)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        Text(initials(for: station.displayName))
          .font(.system(size: size * 0.32, weight: .heavy, design: .rounded))
          .foregroundStyle(.white.opacity(0.95))
      }
    } else {
      ZStack {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(.quaternary)
        Image(systemName: "music.note")
          .font(.system(size: size * 0.28, weight: .semibold))
          .foregroundStyle(.tertiary)
      }
    }
  }

  private func initials(for name: String) -> String {
    let stripped = Station.strippedBrandName(name)
    let letters = stripped.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).prefix(2)
    let result = letters.map { String($0.prefix(1)) }.joined()
    return result.isEmpty ? "IH" : result.uppercased()
  }
}
