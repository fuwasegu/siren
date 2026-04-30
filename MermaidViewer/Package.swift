// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MermaidViewerCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MermaidViewerCore", targets: ["MermaidViewerCore"]),
    ],
    targets: [
        .target(
            name: "MermaidViewerCore",
            path: "Sources"
        ),
        .testTarget(
            name: "MermaidViewerCoreTests",
            dependencies: ["MermaidViewerCore"],
            path: "Tests"
        ),
    ]
)
