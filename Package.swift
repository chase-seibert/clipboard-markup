// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ClipboardMarkup",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClipboardMarkup", targets: ["ClipboardMarkup"]),
        .executable(name: "ClipboardMarkupLoginLauncher", targets: ["ClipboardMarkupLoginLauncher"])
    ],
    targets: [
        .executableTarget(
            name: "ClipboardMarkup",
            dependencies: ["ClipboardMarkupCore"]
        ),
        .executableTarget(
            name: "ClipboardMarkupLoginLauncher"
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
