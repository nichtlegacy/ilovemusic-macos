import Foundation

enum AppIdentity {
  static let displayName = "ILoveMusic"
  static let supportDirectoryName = "ILoveMusic"
  static let keychainService = "ILoveMusic"
  static let bundleIdentifier = "com.nichtlegacy.ILoveMusic"
  static let logSubsystem = bundleIdentifier
  static let menuBarFallbackLabel = "I♥"
  static let historyWindowTitle = "ILoveMusic – History & Stats"
  static let historyWindowTitleResource = LocalizedStringResource(
    "ILoveMusic – History & Stats",
    bundle: #bundle,
    comment: "Title of the listening history and statistics window."
  )
}

enum AppSupportPaths {
  static func supportDirectory(
    fileManager: FileManager = .default,
    applicationSupportURL: URL? = nil
  ) -> URL {
    let baseURL = applicationSupportURL
      ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory())
    let preferredURL = baseURL.appendingPathComponent(AppIdentity.supportDirectoryName, isDirectory: true)

    try? fileManager.createDirectory(at: preferredURL, withIntermediateDirectories: true)
    return preferredURL
  }
}
