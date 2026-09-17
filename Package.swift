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
      resources: [
        .process("Resources")
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
