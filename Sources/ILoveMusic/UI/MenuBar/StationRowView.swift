import AppKit
import SwiftUI

struct StationRow: View {
  let station: Station
  let appModel: AppModel
  let isFavoritesSection: Bool
  let isDetailShown: Bool
  let tracksFrame: Bool
  let onHoverChange: (Bool) -> Void
  let dismissDetail: () -> Void

  @State private var isHovering = false
  private var isActive: Bool { appModel.activeStationID == station.id }
  private var isFavorite: Bool { appModel.preferences.favoriteIDs.contains(station.id) }
  private var accent: Color { Color(hex: station.accentHex) }
  private var metadata: NowPlaying? { appModel.metadata(for: station) }
  private var activePlaybackSymbol: String {
    switch appModel.activePlaybackPhase {
    case .playing, .buffering, .reconnecting:
      return "play.fill"
    case .paused:
      return "pause.fill"
    case .idle, .failed:
      return "play.fill"
    }
  }

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          accent.opacity(isActive ? 0.32 : (isHovering ? 0.18 : 0.10)),
          accent.opacity(isActive ? 0.10 : 0.02)
        ],
        startPoint: .leading,
        endPoint: .trailing
      )

      HStack(spacing: 0) {
        HStack(spacing: 0) {
          ArtworkView(
            station: station,
            currentSongArtworkURL: metadata?.artworkURLString.flatMap(URL.init(string:)),
            size: 44,
            cornerRadius: 0
          )
          .overlay(alignment: .bottomTrailing) {
            if isActive {
              Image(systemName: activePlaybackSymbol)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 16, height: 16)
                .background(.white.opacity(0.92), in: Circle())
                .overlay(
                  Circle()
                    .stroke(accent.opacity(0.8), lineWidth: 1)
                )
                .padding(3)
            }
          }

          VStack(alignment: .leading, spacing: 1) {
            Text(tintedStationName(station.displayName, accent: accent))
              .font(.system(size: 11.5, weight: .heavy))
              .textCase(.uppercase)
              .tracking(0.2)
              .foregroundStyle(.primary)
              .lineLimit(1)

            if let metadata, !metadata.artist.isEmpty {
              Text(metadata.artist)
                .font(.system(size: 9.5, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.15)
                .foregroundStyle(.primary.opacity(0.92))
                .lineLimit(1)
            }
            if let metadata, !metadata.title.isEmpty {
              Text(metadata.title)
                .font(.system(size: 9.5, weight: .regular))
                .textCase(.uppercase)
                .tracking(0.15)
                .foregroundStyle(.primary.opacity(0.7))
                .lineLimit(1)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 10)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: playStation)

        trailingAccessory
      }
    }
    .frame(height: ControlSize.stationRow)
    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
    .overlay(alignment: .leading) {
      if isActive {
        Rectangle()
          .fill(accent)
          .frame(width: 2)
          .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 2)
    .onHover { hovering in
      isHovering = hovering
      onHoverChange(hovering)
    }
    .background {
      if tracksFrame {
        GeometryReader { proxy in
          Color.clear.preference(
            key: StationRowFramePreferenceKey.self,
            value: [station.id: proxy.frame(in: .named("stationList"))]
          )
        }
      }
    }
    .help(station.displayName)
    .stationDetailPopover(
      station: station,
      isPresented: Binding(
        get: { isDetailShown },
        set: { newValue in if !newValue { dismissDetail() } }
      ),
      appModel: appModel,
      onHoverChange: { hovering in onHoverChange(hovering) },
      dismiss: dismissDetail
    )
  }

  @ViewBuilder
  private var trailingAccessory: some View {
    if isFavoritesSection {
      HStack(spacing: 8) {
        if let count = station.listenerCount, count > 0 {
          ListenerBadge(count: count)
        }

        favoriteButton
      }
      .frame(width: 82, height: 44, alignment: .trailing)
      .padding(.trailing, 6)
    } else if isHovering || isFavorite {
      favoriteButton
        .frame(width: 42, height: 44)
        .padding(.trailing, 6)
    } else if let count = station.listenerCount, count > 0 {
      ListenerBadge(count: count)
        .frame(width: 42, height: 44)
        .padding(.trailing, 6)
    } else {
      Spacer()
        .frame(width: 42, height: 44)
    }
  }

  private var favoriteButton: some View {
    Button(action: toggleFavorite) {
      Image(systemName: isFavorite ? "heart.fill" : "heart")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(isFavorite ? accent : .secondary)
        .frame(width: 22, height: 22)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .focusEffectDisabled()
    .frame(width: 22, height: 22)
    .contentShape(Rectangle())
    .onHover { hovering in
      if hovering {
        dismissDetail()
      }
    }
    .help(isFavorite ? "Unfavorite" : "Favorite")
  }

  private func playStation() {
    Task { await appModel.play(station) }
  }

  private func toggleFavorite() {
    dismissDetail()
    appModel.toggleFavorite(station.id)
  }
}

struct ListenerBadge: View {
  let count: Int

  var body: some View {
    HStack(spacing: 3) {
      Image(systemName: "person.fill")
        .font(.system(size: 8, weight: .semibold))
      Text(formatted)
        .font(.system(size: 10, weight: .medium).monospacedDigit())
    }
    .foregroundStyle(.tertiary)
  }

  private var formatted: String {
    if count >= 1000 {
      let value = Double(count) / 1000.0
      return String(format: "%.1fk", value)
    }
    return "\(count)"
  }
}

struct StationListClickInterceptor: NSViewRepresentable {
  let activeDetailStationID: String?
  let rowFrames: [String: CGRect]
  let trailingControlWidth: CGFloat
  let onSelectStationID: (String) -> Void

  func makeNSView(context: Context) -> StationListInterceptView {
    let view = StationListInterceptView()
    view.activeDetailStationID = activeDetailStationID
    view.rowFrames = rowFrames
    view.trailingControlWidth = trailingControlWidth
    view.onSelectStationID = onSelectStationID
    return view
  }

  func updateNSView(_ nsView: StationListInterceptView, context: Context) {
    nsView.activeDetailStationID = activeDetailStationID
    nsView.rowFrames = rowFrames
    nsView.trailingControlWidth = trailingControlWidth
    nsView.onSelectStationID = onSelectStationID
  }

  static func dismantleNSView(_ nsView: StationListInterceptView, coordinator: ()) {
    nsView.stopMonitoring()
  }
}

final class StationListInterceptView: NSView {
  var activeDetailStationID: String?
  var rowFrames: [String: CGRect] = [:]
  var trailingControlWidth: CGFloat = 0
  var onSelectStationID: ((String) -> Void)?

  private var monitor: Any?

  override var isFlipped: Bool { true }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    // Tie the local event monitor to actual window presence. The menu-bar
    // popover is a reused `.transient` NSPopover whose hosting view tree can
    // outlive a close, so relying on `dismantleNSView` alone would leave an
    // app-wide left-mouse-down monitor running while the popover is hidden.
    if window == nil {
      stopMonitoring()
    } else {
      startMonitoring()
    }
  }

  fileprivate func stopMonitoring() {
    if let monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }
  }

  private func startMonitoring() {
    guard monitor == nil else { return }
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
      guard let self else { return event }
      return self.handle(event)
    }
  }

  private func handle(_ event: NSEvent) -> NSEvent? {
    guard activeDetailStationID != nil else { return event }
    guard event.window === window else { return event }

    let point = convert(event.locationInWindow, from: nil)
    guard let stationFrameEntry = rowFrames.first(where: { $0.value.contains(point) }) else {
      return event
    }

    let stationID = stationFrameEntry.key
    let stationFrame = stationFrameEntry.value

    if point.x >= stationFrame.maxX - trailingControlWidth {
      return event
    }

    onSelectStationID?(stationID)
    return nil
  }
}
