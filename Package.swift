// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "CodeEditorView",
  platforms: [
    .macOS(.v12),
    .iOS(.v15)
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
      url: "https://github.com/ChimeHQ/Rearrange",
      .upToNextMajor(from: "1.5.3")),
    .package(
      url: "https://github.com/ChimeHQ/TextViewPlus",
    .upToNextMajor(from: "1.0.5")),
  ],
  targets: [
    .target(
      name: "LanguageSupport",
      dependencies: []),
    .target(
      name: "CodeEditorView",
      dependencies: [
        "LanguageSupport",
        "Rearrange",
        .product(name: "TextViewPlus", package: "TextViewPlus", condition: .when(platforms: [.macOS])),
      ]),
    .testTarget(
      name: "CodeEditorTests",
      dependencies: ["CodeEditorView"]),
  ]
)
