import Foundation

extension Bundle {
  /// The bundle that holds the app's own resources.
  ///
  /// SwiftPM generates a `Bundle.module` that only looks for
  /// `ILoveMusic_ILoveMusic.bundle` next to `Bundle.main.bundleURL`, plus the
  /// absolute `.build` path of the machine that compiled the binary. Inside a
  /// `.app`, `Bundle.main.bundleURL` is the bundle root, and anything placed
  /// there fails `codesign --verify --strict` with "unsealed contents present
  /// in the bundle root". A shipped build therefore only found its resources
  /// through the `.build` fallback, which exists on the build machine and on
  /// no one else's, so every download trapped at launch.
  ///
  /// The app instead ships its resources loose in `Contents/Resources`, the
  /// layout every other macOS app uses, which makes the app bundle itself the
  /// resource bundle. Declaring this accessor (together with the
  /// `SWIFT_MODULE_RESOURCE_BUNDLE_AVAILABLE` define in Package.swift, which
  /// keeps `#bundle` expanding to `Bundle.module`) replaces the generated one.
  static let module: Bundle = resolveResourceBundle()

  private static func resolveResourceBundle() -> Bundle {
    // Running from the .app: resources sit in Contents/Resources.
    if main.url(forResource: "stations_seed", withExtension: "json") != nil {
      return main
    }

    // `swift test` and `swift run` have no .app around the binary, so read the
    // resources straight out of the source tree.
    let sourceResources = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // Support
      .deletingLastPathComponent()  // ILoveMusic
      .appendingPathComponent("Resources")

    return Bundle(url: sourceResources) ?? main
  }
}
