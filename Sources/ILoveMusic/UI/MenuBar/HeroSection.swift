import AppKit
import SwiftUI

struct HeroSection: View {
  let appModel: AppModel
  let playbackController: PlaybackController

  @Environment(\.locale) private var locale
  @State private var isDetailShown = false
  @State private var isHoveringArtwork = false
  @State private var isHoveringNowPlaying = false
  @State private var isHoveringPopover = false
  @State private var showTask: Task<Void, Never>?
  @State private var hideTask: Task<Void, Never>?

  var body: some View {
    let station = appModel.activeStation
    let accent = station.map { Color(hex: $0.accentHex) } ?? .accentColor
    let metadata = appModel.activeMetadata

    VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          ArtworkView(
            station: station,
            currentSongArtworkURL: metadata?.artworkURLString.flatMap(URL.init(string:)),
            size: 118,
            cornerRadius: CornerRadius.xxl
          )
          .onHover { hovering in
            setArtworkHover(hovering: hovering, hasStation: station != nil)
          }

          VStack(alignment: .leading, spacing: 10) {
            if let station {
              ChannelBadge(stationName: station.displayName, accent: accent)
            }

            if let metadata, !metadata.artist.isEmpty || !metadata.title.isEmpty {
              VStack(alignment: .leading, spacing: 3) {
                if !metadata.artist.isEmpty {
                  Text(verbatim: metadata.artist)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .allowsTightening(true)
                }
                if !metadata.title.isEmpty {
                  Text(verbatim: metadata.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(accent.opacity(0.92))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                }
              }
              .onHover { hovering in
                setNowPlayingHover(hovering: hovering, hasStation: station != nil)
              }
            } else {
              VStack(alignment: .leading, spacing: 4) {
                Text(tintedStationName(station?.displayName ?? "ILoveMusic", accent: accent))
                  .font(.system(size: 18, weight: .heavy))
                  .foregroundStyle(.primary)
                  .lineLimit(2)

                if let station {
                  Text(verbatim: station.tagline)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                } else {
                  Text(
                    "Pick a station to start listening",
                    bundle: #bundle,
                    comment: "Prompt shown in the menu-bar panel before a station is selected."
                  )
                  .font(.system(size: 12))
                  .foregroundStyle(.secondary)
                  .lineLimit(2)
                }
              }
              .onHover { hovering in
                setNowPlayingHover(hovering: hovering, hasStation: station != nil)
              }
            }

            HeroMetaRow(
              station: station,
              state: playbackController.state,
              accent: accent
            )
          }
          .frame(minHeight: 116, alignment: .topLeading)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
          // Match the station-row anchor width so the hero popover aligns on the
          // same horizontal axis and keeps the same small gap to the menu.
          Color.clear
            .offset(x: -6)
            .stationDetailPopover(
              station: station,
              isPresented: $isDetailShown,
              appModel: appModel,
              onHoverChange: { hovering in setPopoverHover(hovering: hovering) },
              dismiss: { dismissDetail() }
            )
        }
        .overlay(alignment: .topTrailing) {
          if let station {
            FavoriteButton(
              isFavorite: appModel.preferences.favoriteIDs.contains(station.id),
              accent: accent
            ) {
              appModel.toggleFavorite(station.id)
            }
            .padding(.top, 2)
            .padding(.trailing, 2)
          }
        }
        HStack(alignment: .bottom, spacing: 12) {
          HStack(spacing: 8) {
            PlayPauseButton(
              playbackController: playbackController,
              accentHex: station?.accentHex ?? "#5B6CFF"
            ) {
              Task { await appModel.togglePlayback() }
            }

            IconControlButton(
              systemImage: "forward.fill",
              help: LocalizedStringResource(
                "Next station (⌥⌘N)",
                bundle: #bundle,
                comment: "Help text for the next-station button, including its keyboard shortcut."
              )
            ) {
              Task { await appModel.playNextStation() }
            }

            IconControlButton(
              systemImage: "shuffle",
              help: LocalizedStringResource(
                "Random station",
                bundle: #bundle,
                comment: "Help text for the random-station button."
              )
            ) {
              Task { await appModel.playRandomStation() }
            }

            AirPlayButton()
              .help(Text("AirPlay…", bundle: #bundle, comment: "Help text for the AirPlay output picker."))
              .accessibilityLabel(Text("AirPlay", bundle: #bundle, comment: "Accessibility label for the AirPlay output picker."))
          }
          Spacer(minLength: 0)
          VolumeRow(playbackController: playbackController, appModel: appModel, accent: accent)
        }

        if let error = playbackController.state.errorMessage,
           playbackController.state.phase == .failed {
          playbackErrorText(error)
            .font(.caption)
            .foregroundStyle(.red)
            .lineLimit(2)
        }
    }
    .padding(.horizontal, 16)
    .padding(.top, 14)
    .padding(.bottom, 18)
    .frame(maxWidth: .infinity, alignment: .leading)
    // The closure form pins the gradient to its View interpretation; passed as
    // an argument, `blendMode` is ambiguous between View and ShapeStyle.
    .background {
      LinearGradient(
        colors: [accent.opacity(0.22), accent.opacity(0.05), .clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .blendMode(.plusLighter)
    }
  }

  private var isHoveringInteractiveArea: Bool {
    isHoveringArtwork || isHoveringNowPlaying || isHoveringPopover
  }

  private func playbackErrorText(_ error: String) -> Text {
    switch error {
    case "Stream failed to start.":
      Text(
        LocalizedStringResource(
          "Stream failed to start.",
          locale: locale,
          bundle: #bundle,
          comment: "Playback error shown when the selected radio stream cannot start."
        )
      )
    case "Stream stalled too often.":
      Text(
        LocalizedStringResource(
          "Stream stalled too often.",
          locale: locale,
          bundle: #bundle,
          comment: "Playback error shown after repeated automatic reconnect attempts."
        )
      )
    default:
      Text(verbatim: error)
    }
  }

  private func setArtworkHover(hovering: Bool, hasStation: Bool) {
    isHoveringArtwork = hovering
    updateHoverState(hasStation: hasStation)
  }

  private func setNowPlayingHover(hovering: Bool, hasStation: Bool) {
    isHoveringNowPlaying = hovering
    updateHoverState(hasStation: hasStation)
  }

  private func setPopoverHover(hovering: Bool) {
    isHoveringPopover = hovering
    updateHoverState(hasStation: true)
  }

  private func updateHoverState(hasStation: Bool) {
    if isHoveringInteractiveArea {
      guard hasStation else { return }
      hideTask?.cancel()
      if isDetailShown { return }
      showTask?.cancel()
      showTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(380))
        guard !Task.isCancelled, isHoveringInteractiveArea else { return }
        isDetailShown = true
      }
    } else {
      showTask?.cancel()
      guard isDetailShown else { return }
      hideTask?.cancel()
      hideTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(220))
        guard !Task.isCancelled, !isHoveringInteractiveArea else { return }
        isDetailShown = false
      }
    }
  }

  private func dismissDetail() {
    isDetailShown = false
    isHoveringArtwork = false
    isHoveringNowPlaying = false
    isHoveringPopover = false
    showTask?.cancel()
    hideTask?.cancel()
  }
}

struct PlayPauseButton: View {
  let playbackController: PlaybackController
  let accentHex: String
  let action: () -> Void

  var body: some View {
    let phase = playbackController.state.phase
    let isPlayingLike = phase == .playing || phase == .buffering || phase == .reconnecting
    let accent = Color(hex: accentHex)
    let foreground: Color = relativeLuminance(hex: accentHex) > 0.62 ? .black : .white
    Button(action: action) {
      Image(systemName: isPlayingLike ? "pause.fill" : "play.fill")
        .font(.system(size: 14, weight: .heavy))
        .frame(width: 34, height: 28)
      .foregroundStyle(foreground)
      .background(accent.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
    .buttonStyle(.plain)
    .help(Text(isPlayingLike ? pauseHelp : playHelp))
    .accessibilityLabel(Text(isPlayingLike ? pauseHelp : playHelp))
  }

  private var pauseHelp: LocalizedStringResource {
    LocalizedStringResource(
      "Pause (⌥⌘P)",
      bundle: #bundle,
      comment: "Help text for the pause button, including its keyboard shortcut."
    )
  }

  private var playHelp: LocalizedStringResource {
    LocalizedStringResource(
      "Play (⌥⌘P)",
      bundle: #bundle,
      comment: "Help text for the play button, including its keyboard shortcut."
    )
  }
}

struct FavoriteButton: View {
  let isFavorite: Bool
  let accent: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: isFavorite ? "heart.fill" : "heart")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(isFavorite ? accent : .secondary)
        .frame(width: 24, height: 24)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .focusEffectDisabled()
    .help(Text(isFavorite ? removeHelp : addHelp))
    .accessibilityLabel(Text(isFavorite ? removeHelp : addHelp))
  }

  private var removeHelp: LocalizedStringResource {
    LocalizedStringResource("Remove from favorites", bundle: #bundle, comment: "Action that removes a station from favorites.")
  }

  private var addHelp: LocalizedStringResource {
    LocalizedStringResource("Add to favorites", bundle: #bundle, comment: "Action that adds a station to favorites.")
  }
}

struct IconControlButton: View {
  let systemImage: String
  let help: LocalizedStringResource
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.primary)
        .frame(width: ControlSize.heroControl.width, height: ControlSize.heroControl.height)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .focusEffectDisabled()
    .background(.quaternary, in: RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
    .help(Text(help))
    .accessibilityLabel(Text(help))
  }
}

struct AirPlayButton: View {
  var body: some View {
    AirPlayPicker()
      .frame(width: ControlSize.heroControl.width, height: ControlSize.heroControl.height)
      .background(.quaternary, in: RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
  }
}

struct StatusPill: View {
  let state: PlaybackState
  let accent: Color

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: statusSymbol)
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(dotColor)
      Text(statusTitle)
        .font(.system(size: 10, weight: .semibold))
        .textCase(.uppercase)
        .tracking(0.45)
        .foregroundStyle(.primary.opacity(0.9))
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(accent.opacity(0.16), in: Capsule())
    .overlay(
      Capsule()
        .strokeBorder(accent.opacity(0.18), lineWidth: 1)
    )
  }

  private var statusTitle: LocalizedStringResource {
    switch state.phase {
    case .playing, .buffering, .reconnecting:
      LocalizedStringResource("Live", bundle: #bundle, comment: "Status shown while a station is playing live.")
    case .paused:
      LocalizedStringResource("Paused", bundle: #bundle, comment: "Status shown while playback is paused.")
    case .idle:
      LocalizedStringResource("Ready", bundle: #bundle, comment: "Status shown when the player is ready but idle.")
    case .failed:
      LocalizedStringResource("Failed", bundle: #bundle, comment: "Status shown when playback failed.")
    }
  }

  private var statusSymbol: String {
    switch state.phase {
    case .playing, .buffering, .reconnecting:
      return "dot.radiowaves.left.and.right"
    case .paused:
      return "pause.fill"
    case .idle:
      return "sparkle"
    case .failed:
      return "exclamationmark.triangle.fill"
    }
  }

  private var dotColor: Color {
    switch state.phase {
    case .playing, .buffering, .reconnecting: return accent
    case .failed: return .red
    case .paused: return accent
    case .idle: return accent
    }
  }
}

struct VolumeRow: View {
  let playbackController: PlaybackController
  let appModel: AppModel
  let accent: Color

  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      Button {
        appModel.toggleMute()
      } label: {
        Image(systemName: speakerSymbol)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(playbackController.isMuted ? .red : .secondary)
          .frame(width: 18, height: 18)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .focusEffectDisabled()
      .help(Text(playbackController.isMuted ? unmuteHelp : muteHelp))
      .accessibilityLabel(Text(playbackController.isMuted ? unmuteHelp : muteHelp))

      Slider(
        value: Binding(
          get: { Double(playbackController.volumePercent) },
          set: { appModel.updateVolumePercent(Int($0.rounded())) }
        ),
        in: 0...100
      )
      .frame(width: 104)
      .controlSize(.small)
      .tint(accent)
      .opacity(playbackController.isMuted ? 0.4 : 1)
      .accessibilityLabel(Text("Volume", bundle: #bundle, comment: "Accessibility label for the playback volume slider."))

      Text(
        Double(playbackController.volumePercent) / 100,
        format: .percent.precision(.fractionLength(0))
      )
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 28, alignment: .trailing)
    }
    .frame(width: 166, height: ControlSize.heroControl.height, alignment: .trailing)
  }

  private var speakerSymbol: String {
    if playbackController.isMuted { return "speaker.slash.fill" }
    let v = playbackController.volumePercent
    if v == 0 { return "speaker.fill" }
    if v < 33 { return "speaker.wave.1.fill" }
    if v < 66 { return "speaker.wave.2.fill" }
    return "speaker.wave.3.fill"
  }

  private var unmuteHelp: LocalizedStringResource {
    LocalizedStringResource("Unmute", bundle: #bundle, comment: "Action that turns audio back on.")
  }

  private var muteHelp: LocalizedStringResource {
    LocalizedStringResource("Mute", bundle: #bundle, comment: "Action that turns audio off.")
  }
}

struct ChannelBadge: View {
  let stationName: String
  let accent: Color

  var body: some View {
    Text(tintedStationName(stationName, accent: accent))
      .font(.system(size: 10, weight: .bold))
      .textCase(.uppercase)
      .tracking(0.45)
      .foregroundStyle(.primary.opacity(0.9))
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(accent.opacity(0.16), in: Capsule())
      .overlay(
        Capsule()
          .strokeBorder(accent.opacity(0.18), lineWidth: 1)
      )
  }
}

struct HeroMetaRow: View {
  let station: Station?
  let state: PlaybackState
  let accent: Color

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      if let count = station?.listenerCount, count > 0 {
        Label {
          Text(
            LocalizedStringResource(
              "\(count) listeners",
              bundle: #bundle,
              comment: "Number of people currently listening to a station."
            )
          )
        } icon: {
          Image(systemName: "person.2.fill")
        }
      }
      Spacer(minLength: 0)
      StatusPill(state: state, accent: accent)
    }
    .font(.system(size: 11, weight: .medium))
    .foregroundStyle(.secondary)
    .lineLimit(1)
  }

}
