import Foundation

struct SeedRepository {
  func loadStations() -> [Station] {
    guard
      let url = Bundle.module.url(forResource: "stations_seed", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let stations = try? JSONDecoder().decode([Station].self, from: data)
    else {
      return []
    }

    return stations
  }

  func loadVisibilityPolicy() -> VisibilityPolicy {
    guard
      let url = Bundle.module.url(forResource: "visibility_policy", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let policy = try? JSONDecoder().decode(VisibilityPolicy.self, from: data)
    else {
      return VisibilityPolicy(hiddenRemoteIDs: [])
    }

    return policy
  }
}
