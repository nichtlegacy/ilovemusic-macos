import AppKit
import Darwin
import Dispatch
import Foundation

@main
enum ILoveMusicRelauncher {
  private static let maximumOpenAttempts = 30
  private static let launchServicesSettlingDelay = DispatchTimeInterval.milliseconds(300)

  static func main() {
    guard CommandLine.arguments.count == 3,
          let processIdentifier = Int32(CommandLine.arguments[1]),
          processIdentifier > 1
    else {
      fail("usage: ILoveMusicRelauncher <pid> <app-bundle-path>", status: 64)
    }

    let bundleURL = URL(
      fileURLWithPath: CommandLine.arguments[2],
      isDirectory: true
    ).standardizedFileURL
    guard bundleURL.pathExtension == "app" else {
      fail("relaunch target is not an app bundle", status: 64)
    }

    if kill(processIdentifier, 0) == -1, errno == ESRCH {
      openAfterTerminationSettles(bundleURL)
      dispatchMain()
    }

    let source = DispatchSource.makeProcessSource(
      identifier: processIdentifier,
      eventMask: .exit,
      queue: .main
    )
    source.setEventHandler {
      source.cancel()
      openAfterTerminationSettles(bundleURL)
    }
    source.resume()
    dispatchMain()
  }

  /// Process exit can precede Launch Services unregistering the old app
  /// instance. Give it a brief settling window before requesting a new one.
  private static func openAfterTerminationSettles(_ bundleURL: URL) {
    DispatchQueue.main.asyncAfter(deadline: .now() + launchServicesSettlingDelay) {
      open(bundleURL, remainingAttempts: maximumOpenAttempts)
    }
  }

  private static func open(_ bundleURL: URL, remainingAttempts: Int) {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    configuration.allowsRunningApplicationSubstitution = false
    configuration.promptsUserIfNeeded = false
    NSWorkspace.shared.openApplication(
      at: bundleURL,
      configuration: configuration
    ) { application, error in
      if application != nil {
        exit(0)
      }

      guard remainingAttempts > 1 else {
        fail(
          "could not relaunch app: \(error?.localizedDescription ?? "unknown error")",
          status: 1
        )
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
        open(bundleURL, remainingAttempts: remainingAttempts - 1)
      }
    }
  }

  private static func fail(_ message: String, status: Int32) -> Never {
    fputs("ILoveMusicRelauncher: \(message)\n", stderr)
    exit(status)
  }
}
