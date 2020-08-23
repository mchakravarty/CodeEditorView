// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "CodeEditorView",
  platforms: [
        .macOS(.v11),
//      .macOS(.v10_15),
      .iOS(.v14)
  ],
  products: [
    .library(
      name: "CodeEditorView",
      targets: ["CodeEditorView"]),
  ],
  dependencies: [
      // Dependencies declare other packages that this package depends on.
      // .package(url: /* package url */, from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "CodeEditorView",
      dependencies: []),
    .testTarget(
      name: "CodeEditorTests",
      dependencies: ["CodeEditorView"]),
  ]
)
