// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "CodeEditorView",
  platforms: [
    .macOS(.v13),
    .iOS(.v16)
  ],
  products: [
    .library(
      name: "LanguageSupport",
      targets: ["LanguageSupport"]),
    .library(
      name: "CodeEditorView",
      targets: ["CodeEditorView"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/ChimeHQ/Rearrange.git",
      .upToNextMajor(from: "1.6.0")),
  ],
  targets: [
    .target(
      name: "LanguageSupport",
      dependencies: [
        "Rearrange",
      ]),
    .target(
      name: "CodeEditorView",
      dependencies: [
        "LanguageSupport",
        "Rearrange",
      ]),
    .testTarget(
      name: "CodeEditorTests",
      dependencies: ["CodeEditorView"]),
  ]
)
