import Foundation
import Testing
@testable import ILoveMusic

@Test
func normalizerFiltersNoiseAndBuildsVisibleStations() throws {
  let normalizer = CatalogNormalizer()
  let seed = [
    Station(
      id: "iloveradio",
      remoteID: "1",
      name: "I LOVE RADIO",
      slug: "iloveradio",
      category: .popHits,
      accentHex: "#ffffff",
      aacStreamURLString: nil,
      mp3StreamURLString: nil,
      m3uURLString: "https://www.ilovemusic.de/iloveradio.m3u",
      websiteURLString: "https://ilovemusic.de/iloveradio",
      iconURLString: nil,
      tagline: "Main station",
      featured: true,
      listenerCount: nil
    )
  ]

  let liveChannelsJSON = """
  {
    "1": {
      "id": "1",
      "name": "I LOVE RADIO",
      "segmentname": "iloveradio",
      "streams": {
        "streams": {
          "aac": ["https://play.ilovemusic.de/ilm_iloveradio/?context=fHA6LTE="]
        }
      },
      "cpdConfigdata": {
        "streams": {
          "aac": { "enable": "1" }
        }
      },
      "genre": "Main station"
    },
    "3": {
      "id": "3",
      "name": "DJ MAG PLAYER MODUL",
      "segmentname": "",
      "genre": null
    }
  }
  """

  let playlistJSON = """
  {
    "channel-1": {
      "channel_id": "1",
      "artist": "Artist",
      "title": "Track",
      "cover": "/cover.jpg",
      "color": "#ffffff",
      "segmentname": "iloveradio",
      "channel_type": "Normal"
    }
  }
  """

  let liveChannels = try JSONDecoder().decode(LiveChannelsResponse.self, from: Data(liveChannelsJSON.utf8))
  let playlist = try JSONDecoder().decode(LivePlaylistResponse.self, from: Data(playlistJSON.utf8))

  let result = normalizer.normalize(
    liveChannels: liveChannels,
    playlist: playlist,
    listeners: ["1": 400],
    seedStations: seed,
    visibilityPolicy: VisibilityPolicy(hiddenRemoteIDs: ["3"])
  )

  #expect(result.stations.count == 1)
  #expect(result.stations.first?.remoteID == "1")
  #expect(result.metadataByStationID["iloveradio"]?.artist == "Artist")
  #expect(result.stations.first?.displayName == "I ♥ RADIO")
}

@Test
func mapMetadataSnapshotToleratesDuplicateRemoteIDs() throws {
  let normalizer = CatalogNormalizer()

  func station(id: String, remoteID: String) -> Station {
    Station(
      id: id,
      remoteID: remoteID,
      name: "Station \(id)",
      slug: id,
      category: .popHits,
      accentHex: "#ffffff",
      aacStreamURLString: nil,
      mp3StreamURLString: nil,
      m3uURLString: "https://www.ilovemusic.de/\(id).m3u",
      websiteURLString: "https://ilovemusic.de/\(id)",
      iconURLString: nil,
      tagline: "",
      featured: false,
      listenerCount: nil
    )
  }

  // Two stations sharing the same remoteID must not crash the lookup build.
  let stations = [station(id: "a", remoteID: "1"), station(id: "b", remoteID: "1")]

  let playlistJSON = """
  {
    "channel-1": {
      "channel_id": "1",
      "artist": "Artist",
      "title": "Track"
    }
  }
  """
  let playlist = try JSONDecoder().decode(LivePlaylistResponse.self, from: Data(playlistJSON.utf8))

  let result = normalizer.mapMetadataSnapshot(playlist: playlist, currentStations: stations)
  #expect(result["a"]?.artist == "Artist")
}

@Test
func stationDisplayNameUsesConsistentHeartSpacing() {
  #expect(Station.normalizeDisplayName("I LOVE RADIO") == "I ♥ RADIO")
  #expect(Station.normalizeDisplayName("I♥ROCK RADIO") == "I ♥ ROCK RADIO")
  #expect(Station.normalizeDisplayName("I   HERZ   ROCK RADIO") == "I ♥ ROCK RADIO")
  #expect(Station.strippedBrandName("I♥ROCK RADIO") == "ROCK RADIO")
}
