import AppKit
import Foundation

enum AppRelauncherError: Error {
  case helperUnavailable
}

enum AppRelauncher {
  static let helperExecutableName = "ILoveMusicRelauncher"

  @MainActor
  static func restart() throws {
    let bundleURL = Bundle.main.bundleURL
    let helperURL = helperURL(in: bundleURL)
    guard FileManager.default.isExecutableFile(atPath: helperURL.path) else {
      throw AppRelauncherError.helperUnavailable
    }

    try restart(
      bundleURL: bundleURL,
      processIdentifier: ProcessInfo.processInfo.processIdentifier,
      launch: launchProcess,
      terminate: { NSApplication.shared.terminate(nil) }
    )
  }

  static func restart(
    bundleURL: URL,
    processIdentifier: Int32,
    launch: (_ executable: URL, _ arguments: [String]) throws -> Void,
    terminate: () -> Void
  ) throws {
    try launch(
      helperURL(in: bundleURL),
      [String(processIdentifier), bundleURL.path]
    )
    terminate()
  }

  private static func helperURL(in bundleURL: URL) -> URL {
    bundleURL
      .appendingPathComponent("Contents", isDirectory: true)
      .appendingPathComponent("Helpers", isDirectory: true)
      .appendingPathComponent(helperExecutableName, isDirectory: false)
  }

  private static func launchProcess(executable: URL, arguments: [String]) throws {
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    try process.run()
  }
}
