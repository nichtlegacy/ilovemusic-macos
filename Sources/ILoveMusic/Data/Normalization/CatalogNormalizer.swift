import Foundation

struct CatalogNormalizationResult {
  var stations: [Station]
  var metadataByStationID: [String: NowPlaying]
  var rawStationCount: Int
  var filteredOutCount: Int
}

struct CatalogNormalizer {
  private let coverBaseURL = URL(string: "https://ilovemusic.de")!

  func normalize(
    liveChannels: LiveChannelsResponse,
    playlist: LivePlaylistResponse,
    listeners: [String: Int],
    seedStations: [Station],
    visibilityPolicy: VisibilityPolicy
  ) -> CatalogNormalizationResult {
    let hiddenIDs = Set(visibilityPolicy.hiddenRemoteIDs)
    // Use `uniquingKeysWith` instead of `uniqueKeysWithValues`: duplicate
    // remoteIDs (e.g. a hand-edited seed file) would otherwise trap at runtime.
    let seedByRemoteID = Dictionary(seedStations.map { ($0.remoteID, $0) }, uniquingKeysWith: { first, _ in first })
    let playlistByRemoteID = buildPlaylistLookup(playlist)

    var stations: [Station] = []
    var metadataByStationID: [String: NowPlaying] = [:]
    let rawCount = liveChannels.count

    for (rawID, channel) in liveChannels.sorted(by: { $0.key < $1.key }) {
      let remoteID = (channel.id ?? rawID).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !remoteID.isEmpty, !hiddenIDs.contains(remoteID) else { continue }

      let rawName = (channel.name ?? channel.htmlname ?? "").htmlDecoded.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !rawName.isEmpty else { continue }
      let name = Self.normalizeDisplayName(rawName)

      let streamCandidates = selectStreamCandidates(channel)
      let m3uURLString = buildM3UURL(segmentName: channel.segmentname?.trimmingCharacters(in: .whitespacesAndNewlines))
      let isPlayable = streamCandidates.aac != nil || streamCandidates.mp3 != nil || m3uURLString != nil
      guard isPlayable else { continue }

      if shouldHideAsNoise(channel: channel, remoteID: remoteID, name: name) {
        continue
      }

      let seed = seedByRemoteID[remoteID]
      let playlistEntry = playlistByRemoteID[remoteID]
      let slug = normalizedSlug(
        explicit: channel.segmentname,
        seed: seed?.slug,
        fallbackName: name,
        remoteID: remoteID
      )
      let rawIcon = normalizedAbsoluteURL(channel.icon)
      let iconURLString = (rawIcon?.contains("iloveradio_icon") == true) ? nil : rawIcon
      let accent = (playlistEntry?.color?.isEmpty == false ? playlistEntry?.color : seed?.accentHex) ?? hashColor(for: slug)
      let websiteURLString = seed?.websiteURLString ?? "https://ilovemusic.de/\(slug)"
      let tagline = seed?.tagline ?? channel.genre ?? playlistEntry?.subtitle ?? "\(AppIdentity.displayName) radio stream"
      let category = seed?.category ?? StationCategory.infer(from: name)

      let station = Station(
        id: seed?.id ?? slug,
        remoteID: remoteID,
        name: name,
        slug: slug,
        category: category,
        accentHex: accent,
        aacStreamURLString: streamCandidates.aac ?? seed?.aacStreamURLString,
        mp3StreamURLString: streamCandidates.mp3 ?? seed?.mp3StreamURLString,
        m3uURLString: m3uURLString ?? seed?.m3uURLString,
        websiteURLString: websiteURLString,
        iconURLString: iconURLString ?? seed?.iconURLString,
        tagline: tagline,
        featured: seed?.featured ?? ((listeners[remoteID] ?? 0) > 100),
        listenerCount: listeners[remoteID] ?? seed?.listenerCount
      )
      stations.append(station)

      if let playlistEntry {
        metadataByStationID[station.id] = mapMetadata(playlistEntry, stationID: station.id)
      }
    }

    let sortedStations = stations.sorted { left, right in
      let leftListeners = left.listenerCount ?? 0
      let rightListeners = right.listenerCount ?? 0
      if leftListeners != rightListeners {
        return leftListeners > rightListeners
      }
      return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
    }

    return CatalogNormalizationResult(
      stations: sortedStations,
      metadataByStationID: metadataByStationID,
      rawStationCount: rawCount,
      filteredOutCount: max(0, rawCount - sortedStations.count)
    )
  }

  func mapMetadataSnapshot(
    playlist: LivePlaylistResponse,
    currentStations: [Station]
  ) -> [String: NowPlaying] {
    // Server data can yield two channels sharing the same `channel.id`, which
    // produces stations with duplicate remoteIDs. `uniqueKeysWithValues` would
    // crash on that; keep the first mapping instead.
    let stationIDByRemoteID = Dictionary(
      currentStations.map { ($0.remoteID, $0.id) },
      uniquingKeysWith: { first, _ in first }
    )
    let playlistByRemoteID = buildPlaylistLookup(playlist)
    var result: [String: NowPlaying] = [:]

    for (remoteID, entry) in playlistByRemoteID {
      guard let stationID = stationIDByRemoteID[remoteID] else { continue }
      result[stationID] = mapMetadata(entry, stationID: stationID)
    }

    return result
  }

  func applyListenerCounts(_ listeners: [String: Int], to stations: [Station]) -> [Station] {
    stations
      .map { station in
        var station = station
        station.listenerCount = listeners[station.remoteID] ?? station.listenerCount
        return station
      }
      .sorted { left, right in
        let leftListeners = left.listenerCount ?? 0
        let rightListeners = right.listenerCount ?? 0
        if leftListeners != rightListeners {
          return leftListeners > rightListeners
        }
        return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
      }
  }

  private func selectStreamCandidates(_ channel: LiveChannelDTO) -> (aac: String?, mp3: String?) {
    let directAAC = enabledURL(
      urls: channel.streams?.streams?.aac,
      enabledFlag: channel.cpdConfigdata?.streams?.aac?.enable
    )
    let prerollAAC = enabledURL(
      urls: channel.streams?.prerollstreams?.aac,
      enabledFlag: channel.cpdConfigdata?.prerollstreams?.aac?.enable
    )
    let directMP3 = enabledURL(
      urls: channel.streams?.streams?.mp3,
      enabledFlag: channel.cpdConfigdata?.streams?.mp3?.enable
    )
    let prerollMP3 = enabledURL(
      urls: channel.streams?.prerollstreams?.mp3,
      enabledFlag: channel.cpdConfigdata?.prerollstreams?.mp3?.enable
    )

    return (directAAC ?? prerollAAC, directMP3 ?? prerollMP3)
  }

  private func enabledURL(urls: [String]?, enabledFlag: String?) -> String? {
    guard enabledFlag == nil || enabledFlag == "1" else { return nil }
    return urls?.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
  }

  private func buildPlaylistLookup(_ playlist: LivePlaylistResponse) -> [String: LivePlaylistEntryDTO] {
    var result: [String: LivePlaylistEntryDTO] = [:]
    for (key, entry) in playlist {
      if let explicitID = entry.channel_id?.trimmingCharacters(in: .whitespacesAndNewlines), !explicitID.isEmpty {
        result[explicitID] = entry
      } else {
        result[key.replacingOccurrences(of: "channel-", with: "")] = entry
      }
    }
    return result
  }

  private func normalizedSlug(explicit: String?, seed: String?, fallbackName: String, remoteID: String) -> String {
    if let explicit, !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return explicit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    if let seed, !seed.isEmpty {
      return seed
    }
    let base = fallbackName
      .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
      .replacingOccurrences(of: "♥", with: "love")
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .joined()
      .lowercased()
    return base.isEmpty ? "station-\(remoteID)" : base
  }

  private func buildM3UURL(segmentName: String?) -> String? {
    guard let segmentName, !segmentName.isEmpty else { return nil }
    return "https://www.ilovemusic.de/\(segmentName).m3u"
  }

  private func normalizedAbsoluteURL(_ value: String?) -> String? {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    if value.hasPrefix("http://") || value.hasPrefix("https://") {
      return value.replacingOccurrences(of: "http://", with: "https://")
    }
    guard let resolved = URL(string: value, relativeTo: coverBaseURL)?.absoluteURL else { return nil }
    return resolved.absoluteString
  }

  private func mapMetadata(_ entry: LivePlaylistEntryDTO, stationID: String) -> NowPlaying {
    NowPlaying(
      stationID: stationID,
      artist: (entry.artist ?? "").htmlDecoded.trimmingCharacters(in: .whitespacesAndNewlines),
      title: (entry.title ?? "").htmlDecoded.trimmingCharacters(in: .whitespacesAndNewlines),
      artworkURLString: normalizedAbsoluteURL(entry.cover),
      updatedAt: .now
    )
  }

  private func hashColor(for value: String) -> String {
    var hash = 0
    for scalar in value.unicodeScalars {
      hash = Int(scalar.value) + ((hash << 5) - hash)
    }
    let color = (hash & 0x00ffffff)
    return String(format: "#%06X", color)
  }

  static func normalizeDisplayName(_ raw: String) -> String {
    Station.normalizeDisplayName(raw)
  }

  private func shouldHideAsNoise(channel: LiveChannelDTO, remoteID: String, name: String) -> Bool {
    let normalizedName = name.normalizedStationKey
    if normalizedName.contains("playermodul") {
      return true
    }
    if channel.segmentname?.isEmpty != false && (remoteID == "202" || remoteID == "214") {
      return true
    }
    if remoteID == "100" {
      return true
    }
    return false
  }
}
