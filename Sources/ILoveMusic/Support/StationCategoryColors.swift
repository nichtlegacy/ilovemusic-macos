import SwiftUI

extension StationCategory {
  var chartColor: Color {
    switch self {
    case .popHits: return .pink
    case .danceDJ: return .purple
    case .hipHop: return .orange
    case .throwbacks: return .yellow
    case .chill: return .blue
    case .sport: return .red
    case .party: return .indigo
    case .specials: return .green
    case .seasonal: return .mint
    case .misc: return .gray
    }
  }
}
