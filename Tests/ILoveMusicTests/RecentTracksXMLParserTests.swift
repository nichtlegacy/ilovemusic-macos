import Foundation
import Testing
@testable import ILoveMusic

@Test
func parsesPlaylistPerChannelXMLTracks() throws {
  let xml = """
  <?xml version="1.0"?>
  <xml>
    <track>
      <artist><![CDATA[IVE]]></artist>
      <title><![CDATA[BANG BANG]]></title>
      <songid><![CDATA[53515]]></songid>
      <cover><![CDATA[/fileadmin/coverbilder/ive_bangbang.jpg]]></cover>
      <time><![CDATA[21:31 Uhr]]></time>
    </track>
    <track>
      <artist><![CDATA[BLACKPINK]]></artist>
      <title><![CDATA[SHUT DOWN]]></title>
      <songid><![CDATA[41830]]></songid>
      <cover><![CDATA[/fileadmin/coverbilder/blackpink_shutdown.jpg]]></cover>
      <time><![CDATA[21:28 Uhr]]></time>
    </track>
  </xml>
  """

  let tracks = try LiveRecentTracksXMLParser.parse(Data(xml.utf8))

  #expect(tracks.count == 2)
  #expect(tracks[0].artist == "IVE")
  #expect(tracks[0].title == "BANG BANG")
  #expect(tracks[0].cover == "/fileadmin/coverbilder/ive_bangbang.jpg")
  #expect(tracks[0].timeLabel == "21:31 Uhr")
  #expect(tracks[1].artist == "BLACKPINK")
}
