import Foundation

typealias LiveChannelsResponse = [String: LiveChannelDTO]
typealias LivePlaylistResponse = [String: LivePlaylistEntryDTO]

struct LiveChannelDTO: Codable {
  var id: String?
  var name: String?
  var segmentname: String?
  var streams: LiveStreamContainer?
  var cpdConfigdata: LiveConfigData?
  var icon: String?
  var htmlname: String?
  var genre: String?
  
  enum CodingKeys: String, CodingKey {
    case id, name, segmentname, streams, cpdConfigdata, icon, htmlname, genre
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(String.self, forKey: .id)
    name = try container.decodeIfPresent(String.self, forKey: .name)
    segmentname = try container.decodeIfPresent(String.self, forKey: .segmentname)
    icon = try container.decodeIfPresent(String.self, forKey: .icon)
    htmlname = try container.decodeIfPresent(String.self, forKey: .htmlname)
    genre = try container.decodeIfPresent(String.self, forKey: .genre)
    
    // Safely decode streams (sometimes API returns [] instead of {})
    if let streamsContainer = try? container.decodeIfPresent(LiveStreamContainer.self, forKey: .streams) {
      streams = streamsContainer
    } else {
      streams = nil
    }
    
    // Safely decode config (sometimes API returns [] instead of {})
    if let configData = try? container.decodeIfPresent(LiveConfigData.self, forKey: .cpdConfigdata) {
      cpdConfigdata = configData
    } else {
      cpdConfigdata = nil
    }
  }
}

struct LiveStreamContainer: Codable {
  var streams: LiveStreamValues?
  var prerollstreams: LiveStreamValues?
}

struct LiveStreamValues: Codable {
  var mp3: [String]?
  var aac: [String]?
}

struct LiveConfigData: Codable {
  var streams: LiveStreamEnableSet?
  var prerollstreams: LiveStreamEnableSet?
}

struct LiveStreamEnableSet: Codable {
  var mp3: LiveEnableFlag?
  var aac: LiveEnableFlag?
}

struct LiveEnableFlag: Codable {
  var enable: String?
}

struct LivePlaylistEntryDTO: Codable {
  var channel_id: String?
  var artist: String?
  var title: String?
  var cover: String?
  var color: String?
  var fontcolor: String?
  var segmentname: String?
  var channel_type: String?
  var subtitle: String?
}

struct ListenerCountsResponse: Codable {
  var all: Int?
  var channels: [String: Int]?
}
