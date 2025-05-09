// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "ImmutableData",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
    .macCatalyst(.v13),
  ],
  products: [
    .library(
      name: "AsyncSequenceTestUtils",
      targets: ["AsyncSequenceTestUtils"]
    ),
    .library(
      name: "ImmutableData",
      targets: ["ImmutableData"]
    ),
    .library(
      name: "ImmutableUI",
      targets: ["ImmutableUI"]
    ),
  ],
  targets: [
    .target(
      name: "AsyncSequenceTestUtils"
    ),
    .target(
      name: "ImmutableData"
    ),
    .target(
      name: "ImmutableUI",
      dependencies: ["ImmutableData"]
    ),
    .testTarget(
      name: "AsyncSequenceTestUtilsTests",
      dependencies: ["AsyncSequenceTestUtils"]
    ),
    .testTarget(
      name: "ImmutableDataTests",
      dependencies: ["ImmutableData"]
    ),
    .testTarget(
      name: "ImmutableUITests",
      dependencies: [
        "AsyncSequenceTestUtils",
        "ImmutableUI",
      ]
    ),
  ]
)
