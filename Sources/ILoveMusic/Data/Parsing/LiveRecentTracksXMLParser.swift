import Foundation

struct LiveRecentTrackDTO: Equatable {
  var artist: String
  var title: String
  var cover: String?
  var timeLabel: String?
}

enum LiveRecentTracksXMLParser {
  static func parse(_ data: Data) throws -> [LiveRecentTrackDTO] {
    let delegate = ParserDelegate()
    let parser = XMLParser(data: data)
    parser.delegate = delegate

    guard parser.parse() else {
      throw parser.parserError ?? URLError(.cannotParseResponse)
    }

    return delegate.tracks
  }
}

private final class ParserDelegate: NSObject, XMLParserDelegate {
  private(set) var tracks: [LiveRecentTrackDTO] = []

  private var currentElement: String?
  private var currentText = ""
  private var artist = ""
  private var title = ""
  private var cover: String?
  private var timeLabel: String?

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String] = [:]
  ) {
    currentElement = elementName
    currentText = ""

    if elementName == "track" {
      artist = ""
      title = ""
      cover = nil
      timeLabel = nil
    }
  }

  func parser(_ parser: XMLParser, foundCharacters string: String) {
    currentText += string
  }

  func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

    switch elementName {
    case "artist":
      artist = value
    case "title":
      title = value
    case "cover":
      cover = value.isEmpty ? nil : value
    case "time":
      timeLabel = value.isEmpty ? nil : value
    case "track":
      if !artist.isEmpty || !title.isEmpty {
        tracks.append(
          LiveRecentTrackDTO(
            artist: artist,
            title: title,
            cover: cover,
            timeLabel: timeLabel
          )
        )
      }
    default:
      break
    }

    currentElement = nil
    currentText = ""
  }
}
