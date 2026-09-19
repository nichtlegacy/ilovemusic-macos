import AppKit
import Foundation
import Testing

@testable import ILoveMusic

// Guards the resource/asset loading + bundling invariants verified during the
// resources audit. These lock in that the shipped assets exist in
// `Bundle.module` and that the bundled seed JSON decodes
// against the current `Station` / `VisibilityPolicy` contracts, so a future
// rename or schema drift fails loudly in tests instead of silently degrading
// to an empty catalog at runtime.

@Test
func bundledResourcesArePresentInBundleModule() throws {
  // Both languages need compiled plural resources in direct SwiftPM builds.
  // Outside a built .app, `Bundle.module` is the source resource directory,
  // which carries the `.lproj`s but no Info.plist, so the development region
  // is asserted on the shipping bundle in appBundleResolvesItsOwnResources().
  #expect(Bundle.module.localizations.contains("en"))
  #expect(Bundle.module.localizations.contains("de"))

  // JSON loaders rely on these exact resource names + extensions.
  #expect(Bundle.module.url(forResource: "stations_seed", withExtension: "json") != nil)
  #expect(Bundle.module.url(forResource: "visibility_policy", withExtension: "json") != nil)

  // AboutPane loads the logo by name (extension stripped) via NSBundle.image.
  #expect(Bundle.module.image(forResource: "AppLogo") != nil)

  // AppIcon.icns is a declared, processed resource and must remain bundled.
  #expect(Bundle.module.url(forResource: "AppIcon", withExtension: "icns") != nil)
}

@Test
func appBundleResolvesItsOwnResources() throws {
  // `Bundle.module` falls back to the source tree when no .app is around, so
  // the packaging invariant -- resources land loose in Contents/Resources --
  // has to be asserted against a built bundle. Skip when none was built yet.
  let appURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // ILoveMusicTests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()  // repo root
    .appendingPathComponent(".build/ILoveMusic.app")
  guard let app = Bundle(url: appURL) else { return }

  #expect(app.developmentLocalization == "en")
  #expect(app.localizations.contains("en"))
  #expect(app.localizations.contains("de"))
  #expect(app.url(forResource: "stations_seed", withExtension: "json") != nil)
  #expect(app.url(forResource: "visibility_policy", withExtension: "json") != nil)
  #expect(app.image(forResource: "AppLogo") != nil)
  #expect(app.url(forResource: "AppIcon", withExtension: "icns") != nil)
}

@Test
func seedRepositoryDecodesBundledStations() {
  let stations = SeedRepository().loadStations()

  // A decode failure (rename / schema drift) silently returns []; assert the
  // bundled catalog actually decodes.
  #expect(!stations.isEmpty)

  // Spot-check the contract that all required fields decoded.
  for station in stations {
    #expect(!station.id.isEmpty)
    #expect(!station.remoteID.isEmpty)
    #expect(!station.name.isEmpty)
  }
}

@Test
func seedRepositoryDecodesBundledVisibilityPolicy() {
  let policy = SeedRepository().loadVisibilityPolicy()

  // The bundled policy hides a known set of remote IDs; a decode failure would
  // fall back to an empty set.
  #expect(!policy.hiddenRemoteIDs.isEmpty)
}

@Test
func menuBarIconReturnsTemplateImage() {
  let image = MenuBarIcon.image()

  #expect(image.isTemplate)
  #expect(image.size.width > 0)
  #expect(image.size.height > 0)
  #expect(image.accessibilityDescription == AppIdentity.displayName)
}
