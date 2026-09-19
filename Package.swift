// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "ILoveMusic",
  defaultLocalization: "en",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "ILoveMusic", targets: ["ILoveMusic"]),
    .executable(name: "ILoveMusicRelauncher", targets: ["ILoveMusicRelauncher"])
  ],
  dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
  ],
  targets: [
    .executableTarget(
      name: "ILoveMusic",
      dependencies: [
        .product(name: "Sparkle", package: "Sparkle")
      ],
      exclude: ["Resources"],
      swiftSettings: [
        // Resources ship loose in the .app's Contents/Resources and are reached
        // through the Bundle.module accessor in ResourceBundle.swift, not
        // through a SwiftPM resource bundle. `#bundle` only expands when a
        // module advertises one, so set the flag SwiftPM would have set.
        .define("SWIFT_MODULE_RESOURCE_BUNDLE_AVAILABLE")
      ],
      linkerSettings: [
        .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
      ]
    ),
    .executableTarget(
      name: "ILoveMusicRelauncher"
    ),
    .testTarget(
      name: "ILoveMusicTests",
      dependencies: ["ILoveMusic"]
    )
  ]
)
