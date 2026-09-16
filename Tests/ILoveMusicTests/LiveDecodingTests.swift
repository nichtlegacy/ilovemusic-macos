import Foundation
import Testing
@testable import ILoveMusic

@Test
func decodesCurrentLiveChannelShape() throws {
  let json = """
  {
    "1": {
      "id": "1",
      "name": "I LOVE RADIO",
      "segmentname": "iloveradio",
      "streams": {
        "streams": {
          "aac": ["https://play.ilovemusic.de/ilm_iloveradio/?context=fHA6LTE="]
        },
        "prerollstreams": {
          "mp3": ["https://play.ilovemusic.de/ilm_iloveradio/"]
        }
      },
      "cpdConfigdata": {
        "streams": { "aac": { "enable": "1" } },
        "prerollstreams": { "mp3": { "enable": "1" } }
      },
      "icon": "http://www.iloveradio.de/fileadmin/templates/img/iloveradio_icon_sw_400x400.png",
      "genre": "Main station"
    }
  }
  """

  let decoded = try JSONDecoder().decode(LiveChannelsResponse.self, from: Data(json.utf8))
  #expect(decoded["1"]?.name == "I LOVE RADIO")
  #expect(decoded["1"]?.streams?.streams?.aac?.first == "https://play.ilovemusic.de/ilm_iloveradio/?context=fHA6LTE=")
}
