import SwiftUI

struct StationsScrollView: View {
  let appModel: AppModel

  @State private var detailStationID: String?
  @State private var hoverTargetStationID: String?
  @State private var showDetailTask: Task<Void, Never>?
  @State private var hideDetailTask: Task<Void, Never>?
  @State private var rowFrames: [String: CGRect] = [:]

  var body: some View {
    let favoriteStations = appModel.favoriteStations
    let channelStations = appModel.channelStations
    let totalListeners = channelStations.reduce(0) { $0 + ($1.listenerCount ?? 0) }
    let tracksRowFrames = detailStationID != nil

    ZStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          Section {
            if favoriteStations.isEmpty {
              Text("Tap the heart on any station to pin it here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            } else {
              ForEach(favoriteStations) { station in
                rowFor(station, tracksFrame: tracksRowFrames, isFavoritesSection: true)
              }
            }
          } header: {
            SectionHeader(
              title: "Favorites",
              channelCount: favoriteStations.isEmpty ? nil : favoriteStations.count
            )
          }

          Section {
            ForEach(channelStations) { station in
              rowFor(station, tracksFrame: tracksRowFrames, isFavoritesSection: false)
            }
          } header: {
            SectionHeader(
              title: "All Channels",
              channelCount: channelStations.count,
              listenerTotal: totalListeners > 0 ? totalListeners : nil
            )
          }

          Color.clear.frame(height: 4)
        }
      }
      .scrollIndicators(.never)
      .coordinateSpace(name: "stationList")
      .onPreferenceChange(StationRowFramePreferenceKey.self) { frames in
        guard tracksRowFrames else { return }
        rowFrames = frames
      }

      if tracksRowFrames {
        StationListClickInterceptor(
          activeDetailStationID: detailStationID,
          rowFrames: rowFrames,
          trailingControlWidth: 88,
          onSelectStationID: playStationFromIntercept
        )
        .allowsHitTesting(false)
      }
    }
  }

  @ViewBuilder
  private func rowFor(_ station: Station, tracksFrame: Bool, isFavoritesSection: Bool) -> some View {
    StationRow(
      station: station,
      appModel: appModel,
      isFavoritesSection: isFavoritesSection,
      isDetailShown: detailStationID == station.id,
      tracksFrame: tracksFrame,
      onHoverChange: { hovering in handleHover(for: station.id, hovering: hovering) },
      dismissDetail: {
        dismissDetail(for: station.id)
      }
    )
  }

  private func handleHover(for stationID: String, hovering: Bool) {
    if hovering {
      hoverTargetStationID = stationID
      hideDetailTask?.cancel()

      if detailStationID == stationID { return }

      showDetailTask?.cancel()

      if detailStationID != nil {
        detailStationID = stationID
        return
      }

      showDetailTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(380))
        guard !Task.isCancelled, hoverTargetStationID == stationID else { return }
        detailStationID = stationID
      }
    } else {
      if hoverTargetStationID == stationID {
        hoverTargetStationID = nil
      }

      showDetailTask?.cancel()

      guard detailStationID == stationID else { return }
      hideDetailTask?.cancel()
      hideDetailTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(220))
        guard !Task.isCancelled, hoverTargetStationID == nil, detailStationID == stationID else { return }
        detailStationID = nil
      }
    }
  }

  private func dismissDetail(for stationID: String) {
    if detailStationID == stationID {
      detailStationID = nil
    }
    if hoverTargetStationID == stationID {
      hoverTargetStationID = nil
    }
    showDetailTask?.cancel()
    hideDetailTask?.cancel()
    if detailStationID == nil {
      rowFrames = [:]
    }
  }

  private func dismissAllDetail() {
    detailStationID = nil
    hoverTargetStationID = nil
    showDetailTask?.cancel()
    hideDetailTask?.cancel()
    rowFrames = [:]
  }

  private func playStationFromIntercept(_ stationID: String) {
    guard let station = appModel.visibleStations.first(where: { $0.id == stationID }) else { return }
    dismissAllDetail()
    Task { await appModel.play(station) }
  }
}

struct StationRowFramePreferenceKey: PreferenceKey {
  static let defaultValue: [String: CGRect] = [:]

  static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}

struct SectionHeader: View {
  let title: String
  let channelCount: Int?
  var listenerTotal: Int? = nil

  init(title: String, channelCount: Int?, listenerTotal: Int? = nil) {
    self.title = title
    self.channelCount = channelCount
    self.listenerTotal = listenerTotal
  }

  var body: some View {
    HStack(spacing: 10) {
      Text(title)
        .font(.system(size: 10, weight: .semibold))
        .textCase(.uppercase)
        .tracking(0.6)
        .foregroundStyle(.secondary)
      Spacer()
      if let listenerTotal {
        SectionHeaderBadge(systemImage: "person.fill", value: listenerTotal)
      }
      if let channelCount {
        SectionHeaderBadge(systemImage: "dot.radiowaves.left.and.right", value: channelCount)
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .padding(.bottom, 4)
  }
}

struct SectionHeaderBadge: View {
  let systemImage: String
  let value: Int

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: systemImage)
        .font(.system(size: 9, weight: .semibold))
        .frame(width: 10)
      Text("\(value)")
        .font(.system(size: 10, weight: .medium).monospacedDigit())
    }
    .foregroundStyle(.tertiary)
  }
}
