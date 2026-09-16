import AppKit
import SwiftUI

extension View {
  /// Attaches the station-detail hover popover used by both the hero and the
  /// station rows. Lives at module scope (not `fileprivate`) so HeroSection
  /// and StationRow can share it.
  func stationDetailPopover(
    station: Station?,
    isPresented: Binding<Bool>,
    appModel: AppModel,
    onHoverChange: @escaping (Bool) -> Void,
    dismiss: @escaping () -> Void
  ) -> some View {
    self.popover(
      isPresented: Binding(
        get: { isPresented.wrappedValue && station != nil },
        set: { newValue in if !newValue { dismiss() } }
      ),
      arrowEdge: .leading
    ) {
      if let station {
        StationDetailPopover(
          station: station,
          appModel: appModel,
          onPlay: {
            Task { await appModel.play(station) }
            dismiss()
          },
          onToggleFavorite: { appModel.toggleFavorite(station.id) },
          onOpenWebsite: {
            if let url = URL(string: station.websiteURLString) {
              NSWorkspace.shared.open(url)
            }
          }
        )
        .onHover { hovering in onHoverChange(hovering) }
      }
    }
  }
}

struct StationDetailPopover: View {
  let station: Station
  let appModel: AppModel
  let onPlay: () -> Void
  let onToggleFavorite: () -> Void
  let onOpenWebsite: () -> Void

  private var accent: Color { Color(hex: station.accentHex) }
  private var nowPlaying: NowPlaying? { appModel.metadata(for: station) }
  private var recent: [NowPlaying] { appModel.stationRecentSongs(for: station) }
  private var isFav: Bool { appModel.preferences.favoriteIDs.contains(station.id) }
  private var isActive: Bool { appModel.activeStationID == station.id }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      Divider()
      nowPlayingSection
      if !recent.isEmpty {
        Divider()
        recentSection
      }
      Divider()
      actions
    }
    .padding(14)
    .frame(width: 280)
    .background(
      LinearGradient(
        colors: [accent.opacity(0.12), .clear],
        startPoint: .top,
        endPoint: .bottom
      )
    )
    .task(id: appModel.recentSongsTaskID(for: station)) {
      await appModel.loadRecentSongsIfNeeded(for: station)
    }
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 12) {
      ArtworkView(
        station: station,
        currentSongArtworkURL: nowPlaying?.artworkURLString.flatMap(URL.init(string:)),
        size: 60,
        cornerRadius: 8
      )
      VStack(alignment: .leading, spacing: 4) {
        Text(tintedStationName(station.displayName, accent: accent))
          .font(.system(size: 13, weight: .heavy))
          .textCase(.uppercase)
          .tracking(0.3)
          .foregroundStyle(.primary)
          .fixedSize(horizontal: false, vertical: true)
        if let count = station.listenerCount, count > 0 {
          HStack(spacing: 4) {
            Image(systemName: "person.fill")
              .font(.system(size: 9))
            Text("\(count) listening")
              .font(.system(size: 10, weight: .medium))
          }
          .foregroundStyle(.secondary)
        }
      }
      Spacer(minLength: 0)
    }
  }

  private var nowPlayingSection: some View {
    VStack(alignment: .leading, spacing: 4) {
      sectionHeader("Now playing")
      if let nowPlaying, !nowPlaying.artist.isEmpty || !nowPlaying.title.isEmpty {
        if !nowPlaying.artist.isEmpty {
          Text(nowPlaying.artist)
            .font(.system(size: 11, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.2)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
        }
        if !nowPlaying.title.isEmpty {
          Text(nowPlaying.title)
            .font(.system(size: 11))
            .textCase(.uppercase)
            .tracking(0.2)
            .foregroundStyle(.primary.opacity(0.78))
            .fixedSize(horizontal: false, vertical: true)
        }
      } else {
        Text("Not on air right now.")
          .font(.system(size: 10.5))
          .foregroundStyle(.secondary)
      }
    }
  }

  private var recentSection: some View {
    VStack(alignment: .leading, spacing: 5) {
      sectionHeader("Recent")
      ForEach(Array(recent.prefix(5).enumerated()), id: \.offset) { _, entry in
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(entry.updatedAt.formatted(date: .omitted, time: .shortened))
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundStyle(.tertiary)
            .frame(width: 38, alignment: .leading)
          Text(entry.displayLine)
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 0)
        }
      }
    }
  }

  private var actions: some View {
    HStack(spacing: 8) {
      Button(action: onPlay) {
        HStack(spacing: 5) {
          Image(systemName: isActive ? "arrow.clockwise" : "play.fill")
            .font(.system(size: 10, weight: .heavy))
          Text(isActive ? "Restart" : "Play")
            .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 12)
        .frame(height: 26)
        .foregroundStyle(relativeLuminance(hex: station.accentHex) > 0.62 ? .black : .white)
        .background(accent.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
      }
      .buttonStyle(.plain)
      .focusEffectDisabled()

      Button(action: onToggleFavorite) {
        Image(systemName: isFav ? "heart.fill" : "heart")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(isFav ? accent : .secondary)
          .frame(width: 26, height: 26)
          .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .focusEffectDisabled()
      .help(isFav ? "Remove from favorites" : "Add to favorites")

      Spacer()

      Button(action: onOpenWebsite) {
        HStack(spacing: 5) {
          Text("Website")
            .font(.system(size: 11, weight: .semibold))
          Image(systemName: "arrow.up.right")
            .font(.system(size: 9, weight: .bold))
        }
        .padding(.horizontal, 12)
        .frame(height: 26)
        .foregroundStyle(.primary)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
      }
      .buttonStyle(.plain)
      .focusEffectDisabled()
      .help("Open ilovemusic.de")
    }
  }

  private func sectionHeader(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 9, weight: .semibold))
      .textCase(.uppercase)
      .tracking(0.6)
      .foregroundStyle(.tertiary)
  }
}
