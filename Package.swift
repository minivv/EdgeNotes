// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "EdgeNotes",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "EdgeNotes", targets: ["EdgeNotes"])
  ],
  dependencies: [
    .package(url: "https://github.com/nodes-app/swift-markdown-engine.git", from: "0.8.0")
  ],
  targets: [
    .executableTarget(
      name: "EdgeNotes",
      dependencies: [
        .product(name: "MarkdownEngine", package: "swift-markdown-engine")
      ],
      path: "Sources/EdgeNotes",
      resources: [
        .process("Resources")
      ]
    ),
    .testTarget(
      name: "EdgeNotesTests",
      dependencies: ["EdgeNotes"],
      path: "Tests/EdgeNotesTests"
    )
  ]
)
