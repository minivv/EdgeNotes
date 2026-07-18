// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "EdgeNotes",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "EdgeNotes", targets: ["EdgeNotes"]),
    .executable(name: "edgenotes-cli", targets: ["EdgeNotesCLI"]),
    .library(name: "EdgeNotesIPC", targets: ["EdgeNotesIPC"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    .package(url: "https://github.com/nodes-app/swift-markdown-engine.git", from: "0.8.0")
  ],
  targets: [
    .target(
      name: "EdgeNotesIPC",
      path: "Sources/EdgeNotesIPC"
    ),
    .executableTarget(
      name: "EdgeNotes",
      dependencies: [
        "EdgeNotesIPC",
        .product(name: "MarkdownEngine", package: "swift-markdown-engine")
      ],
      path: "Sources/EdgeNotes",
      resources: [
        .process("Resources")
      ]
    ),
    .executableTarget(
      name: "EdgeNotesCLI",
      dependencies: [
        "EdgeNotesIPC",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ],
      path: "Sources/EdgeNotesCLI"
    ),
    .testTarget(
      name: "EdgeNotesTests",
      dependencies: ["EdgeNotes", "EdgeNotesIPC"],
      path: "Tests/EdgeNotesTests"
    )
  ]
)
