import Foundation
import Testing

@testable import ILoveMusic

@Suite("App relauncher")
struct AppRelauncherTests {
  @Test
  func launchesBundledHelperBeforeTerminating() throws {
    let bundleURL = URL(fileURLWithPath: "/Applications/ILoveMusic.app", isDirectory: true)
    var launchedExecutable: URL?
    var launchedArguments: [String] = []
    var didTerminate = false

    try AppRelauncher.restart(
      bundleURL: bundleURL,
      processIdentifier: 42,
      launch: { executable, arguments in
        launchedExecutable = executable
        launchedArguments = arguments
      },
      terminate: {
        #expect(launchedExecutable != nil)
        didTerminate = true
      }
    )

    #expect(
      launchedExecutable?.path
        == "/Applications/ILoveMusic.app/Contents/Helpers/ILoveMusicRelauncher"
    )
    #expect(launchedArguments == ["42", "/Applications/ILoveMusic.app"])
    #expect(didTerminate)
  }

  @Test
  func launchFailureKeepsApplicationRunning() {
    enum TestFailure: Error { case launch }

    var didTerminate = false

    #expect(throws: TestFailure.self) {
      try AppRelauncher.restart(
        bundleURL: URL(fileURLWithPath: "/Applications/ILoveMusic.app", isDirectory: true),
        processIdentifier: 42,
        launch: { _, _ in throw TestFailure.launch },
        terminate: { didTerminate = true }
      )
    }
    #expect(!didTerminate)
  }
}
