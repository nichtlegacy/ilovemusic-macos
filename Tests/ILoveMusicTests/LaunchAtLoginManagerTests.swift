import Foundation
import Testing
@testable import ILoveMusic

@Suite("Launch at login reporting")
struct LaunchAtLoginManagerTests {

  @Test
  func reportsUnavailableOutsideAnAppBundle() {
    // The test runner is not an .app, which is the same situation as `swift run`.
    // The manager must say so instead of reporting success for a login item it
    // never registered.
    let manager = LaunchAtLoginManager()

    #expect(manager.setEnabled(true) == .unavailable)
    #expect(manager.isRegistered == false)
  }

  @Test
  func onlyProblemStatesCarryAUserFacingMessage() {
    #expect(LaunchAtLoginStatus.off.message == nil)
    #expect(LaunchAtLoginStatus.enabled.message == nil)
    #expect(LaunchAtLoginStatus.unavailable.message != nil)
    #expect(LaunchAtLoginStatus.failed(reason: "denied").message?.contains("denied") == true)
  }
}
