import Foundation
import Testing
@testable import ILoveMusic

@MainActor
private final class OperationLog {
  private(set) var entries: [String] = []

  func append(_ entry: String) {
    entries.append(entry)
  }
}

@Suite("Refresh serialization")
@MainActor
struct RefreshSerializerTests {

  @Test
  func concurrentOperationsNeverInterleave() async {
    let serializer = RefreshSerializer()
    let log = OperationLog()

    var tasks: [Task<Void, Never>] = []
    for index in 0..<5 {
      tasks.append(Task { @MainActor in
        await serializer.run {
          log.append("start-\(index)")
          try? await Task.sleep(for: .milliseconds(5))
          log.append("end-\(index)")
        }
      })
    }
    for task in tasks {
      await task.value
    }

    #expect(log.entries.count == 10)
    #expect(serializer.completedCount == 5)

    // Whatever order the group schedules them in, every operation must finish
    // before the next one starts. Without the serializer the log would read
    // five starts followed by five ends.
    for pair in stride(from: 0, to: log.entries.count, by: 2) {
      let start = log.entries[pair]
      let end = log.entries[pair + 1]
      #expect(start.hasPrefix("start-"))
      #expect(end.hasPrefix("end-"))
      #expect(start.dropFirst("start-".count) == end.dropFirst("end-".count))
    }
  }

  @Test
  func returnsEachOperationsOwnResult() async {
    let serializer = RefreshSerializer()

    let boolResult = await serializer.run { true }
    let intResult = await serializer.run { 42 }

    #expect(boolResult)
    #expect(intResult == 42)
    #expect(serializer.completedCount == 2)
  }
}
