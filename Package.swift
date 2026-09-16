// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "ILoveMusic",
  defaultLocalization: "en",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "ILoveMusic", targets: ["ILoveMusic"])
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
      resources: [
        .process("Resources")
      ],
      linkerSettings: [
        .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
      ]
    ),
    .testTarget(
      name: "ILoveMusicTests",
      dependencies: ["ILoveMusic"]
    )
  ]
)
