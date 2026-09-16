import Foundation

/// Runs refresh operations strictly one after another.
///
/// The three background loops and the manual "Refresh" action call the same
/// `AppModel` entry points. Being on the main actor prevents memory races, but
/// not ordering ones: an automatic catalog refresh started before a manual one
/// can still return after it and write its older snapshot over the newer data.
///
/// Queuing the operations removes that window. Each call waits for the
/// previously queued one to finish, so a refresh always reads and writes state
/// that no other refresh is midway through changing.
@MainActor
final class RefreshSerializer {
  private var tail: Task<Void, Never>?

  /// Number of operations completed. Tests use this to assert ordering.
  private(set) var completedCount = 0

  func run<T: Sendable>(_ operation: @escaping @MainActor () async -> T) async -> T {
    let previous = tail
    let task = Task { @MainActor () -> T in
      await previous?.value
      let result = await operation()
      self.completedCount += 1
      return result
    }
    // `tail` is type-erased so operations with different result types can queue
    // behind one another.
    tail = Task { @MainActor in _ = await task.value }
    return await task.value
  }
}
