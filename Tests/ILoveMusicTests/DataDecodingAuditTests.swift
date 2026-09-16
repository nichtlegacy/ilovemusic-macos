import Foundation
import Testing
@testable import ILoveMusic

// MARK: - URLProtocol stub

private final class StubURLProtocol: URLProtocol {
  struct Stub {
    var statusCode: Int
    var body: Data
  }

  nonisolated(unsafe) static var stub: Stub?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let stub = StubURLProtocol.stub, let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.unknown))
      return
    }
    let response = HTTPURLResponse(
      url: url,
      statusCode: stub.statusCode,
      httpVersion: "HTTP/1.1",
      headerFields: nil
    )!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: stub.body)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

private func makeClient(statusCode: Int, body: String) -> ILoveMusicAPIClient {
  StubURLProtocol.stub = .init(statusCode: statusCode, body: Data(body.utf8))
  let config = URLSessionConfiguration.ephemeral
  config.protocolClasses = [StubURLProtocol.self]
  return ILoveMusicAPIClient(session: URLSession(configuration: config))
}

// MARK: - HTTP status is honored (error HTML body must not decode as success)
//
// Serialized because the stub state lives in a shared static on the URLProtocol
// subclass; parallel execution would race on it.

@Suite(.serialized)
struct HTTPStatusHonoredTests {
  @Test
  func channelsFetchRejectsHTTPErrorBody() async {
    let client = makeClient(statusCode: 500, body: "<html><body>Internal Server Error</body></html>")
    await #expect(throws: (any Error).self) {
      _ = try await client.fetchChannels()
    }
  }

  @Test
  func m3uFetchRejectsHTTPErrorBody() async {
    // Before the fix an HTML 404 page would be returned verbatim as a valid M3U string.
    let client = makeClient(statusCode: 404, body: "<html>Not Found</html>")
    await #expect(throws: (any Error).self) {
      _ = try await client.fetchM3U(url: URL(string: "https://ilovemusic.de/x.m3u")!)
    }
  }

  @Test
  func recentTracksFetchRejectsHTTPErrorBody() async {
    let client = makeClient(statusCode: 503, body: "<html>down</html>")
    await #expect(throws: (any Error).self) {
      _ = try await client.fetchRecentTracks(channelID: "1", date: .now)
    }
  }

  @Test
  func m3uFetchAcceptsSuccessfulBody() async throws {
    let client = makeClient(statusCode: 200, body: "#EXTM3U\nhttps://stream.example/aac")
    let text = try await client.fetchM3U(url: URL(string: "https://ilovemusic.de/x.m3u")!)
    #expect(text.contains("#EXTM3U"))
  }
}

// MARK: - XML parser robustness

@Test
func xmlParserHandlesCharactersSplitAcrossCallbacks() throws {
  // No CDATA: entities and plain text exercise the foundCharacters accumulation path.
  let xml = """
  <?xml version="1.0"?>
  <xml>
    <track>
      <artist>AC &amp; DC</artist>
      <title>Long &amp; Winding Title</title>
      <cover>/a.jpg</cover>
      <time>10:05 Uhr</time>
    </track>
  </xml>
  """
  let tracks = try LiveRecentTracksXMLParser.parse(Data(xml.utf8))
  #expect(tracks.count == 1)
  #expect(tracks[0].artist == "AC & DC")
  #expect(tracks[0].title == "Long & Winding Title")
}

@Test
func xmlParserSkipsEmptyTracksAndKeepsNilCover() throws {
  let xml = """
  <?xml version="1.0"?>
  <xml>
    <track></track>
    <track>
      <artist>Solo</artist>
      <title></title>
    </track>
  </xml>
  """
  let tracks = try LiveRecentTracksXMLParser.parse(Data(xml.utf8))
  #expect(tracks.count == 1)
  #expect(tracks[0].artist == "Solo")
  #expect(tracks[0].cover == nil)
  #expect(tracks[0].timeLabel == nil)
}
