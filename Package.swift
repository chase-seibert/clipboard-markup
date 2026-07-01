// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ClipboardMarkup",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClipboardMarkup", targets: ["ClipboardMarkup"])
    ],
    targets: [
        .executableTarget(
            name: "ClipboardMarkup",
            dependencies: ["ClipboardMarkupCore"]
        ),
        .target(
            name: "ClipboardMarkupCore",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ClipboardMarkupCoreTests",
            dependencies: ["ClipboardMarkupCore"]
        )
    ]
)
