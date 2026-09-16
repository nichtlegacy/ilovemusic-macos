import Foundation
import os

struct ILoveMusicAPIClient {
  private let session: URLSession
  private let decoder = JSONDecoder()
  private let logger = Logger(subsystem: AppIdentity.logSubsystem, category: "APIClient")
  private let recentDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private let channelsURL = URL(string: "https://ilovemusic.de/typo3conf/ext/ep_channel/Scripts/listChannels.php")!
  private let playlistURL = URL(string: "https://ilovemusic.de/typo3conf/ext/ep_channel/Scripts/playlist.php")!
  private let listenersURL = URL(string: "https://ilovemusic.de/fileadmin/user_upload/listener_counter.json?source=getChannelListener")!
  private let playlistPerChannelURL = URL(string: "https://ilovemusic.de/typo3conf/ext/ep_channel/Scripts/playlistPerChannel.php")!

  init(session: URLSession = .shared) {
    self.session = session
  }

  func fetchChannels() async throws -> LiveChannelsResponse {
    try await fetchJSON(url: channelsURL, as: LiveChannelsResponse.self)
  }

  func fetchPlaylist() async throws -> LivePlaylistResponse {
    try await fetchJSON(url: playlistURL, as: LivePlaylistResponse.self)
  }

  func fetchListenerCounts() async throws -> ListenerCountsResponse {
    try await fetchJSON(url: listenersURL, as: ListenerCountsResponse.self)
  }

  func fetchRecentTracks(channelID: String, date: Date) async throws -> [LiveRecentTrackDTO] {
    var components = URLComponents(url: playlistPerChannelURL, resolvingAgainstBaseURL: false)
    components?.queryItems = [
      URLQueryItem(name: "tx_epchannel_channellist[from]", value: "latest"),
      URLQueryItem(name: "tx_epchannel_channellist[till]", value: "latest"),
      URLQueryItem(name: "tx_epchannel_channellist[date]", value: recentDateFormatter.string(from: date)),
      URLQueryItem(name: "tx_epchannel_channellist[channel]", value: channelID)
    ]

    guard let url = components?.url else {
      throw URLError(.badURL)
    }

    let (data, response) = try await session.data(from: url)
    try validate(response: response, url: url)
    return try LiveRecentTracksXMLParser.parse(data)
  }

  func fetchM3U(url: URL) async throws -> String {
    let (data, response) = try await session.data(from: url)
    try validate(response: response, url: url)
    guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
      throw URLError(.cannotDecodeContentData)
    }
    return text
  }

  /// Rejects non-success HTTP responses so an HTML error page (404/500) is not
  /// fed to the JSON/XML decoders or returned as a "successful" M3U payload.
  private func validate(response: URLResponse, url: URL) throws {
    guard let http = response as? HTTPURLResponse else { return }
    guard (200...299).contains(http.statusCode) else {
      logger.error("HTTP \(http.statusCode, privacy: .public) for \(url.lastPathComponent, privacy: .public)")
      throw URLError(.badServerResponse)
    }
  }

  private func fetchJSON<T: Decodable>(url: URL, as type: T.Type) async throws -> T {
    do {
      let (data, response) = try await session.data(from: url)
      try validate(response: response, url: url)
      do {
        return try decoder.decode(T.self, from: data)
      } catch {
        logger.error("decode failed for \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        throw error
      }
    } catch {
      logger.error("fetch failed for \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
      throw error
    }
  }
}
