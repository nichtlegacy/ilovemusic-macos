import Foundation

enum StreamDeckConnectionStatus: Equatable {
  case issue
  case receivingRequests
  case idle
  case waitingForPlugin

  static func resolve(
    runtime: ControlServerRuntimeStatus,
    now: Date,
    recentRequestInterval: TimeInterval = 5 * 60
  ) -> Self {
    if
      let errorAt = runtime.lastErrorAt,
      runtime.lastRequestAt.map({ errorAt >= $0 }) ?? true
    {
      return .issue
    }
    guard let requestAt = runtime.lastRequestAt else { return .waitingForPlugin }
    return now.timeIntervalSince(requestAt) < recentRequestInterval ? .receivingRequests : .idle
  }
}
