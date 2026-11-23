// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AxonFlow",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "AxonFlowCore", targets: ["AxonFlowCore"]),
        .library(name: "AxonFlowUI", targets: ["AxonFlowUI"]),
        .executable(name: "AxonFlow", targets: ["AxonFlow"]),
        .executable(name: "AxonFlowTools", targets: ["AxonFlowTools"])
    ],
    targets: [
        .target(
            name: "AxonFlowCore",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("AppKit")
            ]
        ),
        .target(
            name: "AxonFlowUI",
            dependencies: ["AxonFlowCore"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "AxonFlow",
            dependencies: ["AxonFlowCore", "AxonFlowUI"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        ),
        .executableTarget(
            name: "AxonFlowTools",
            dependencies: ["AxonFlowCore", "AxonFlowUI"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics")
            ]
        ),
        .testTarget(
            name: "AxonFlowTests",
            dependencies: ["AxonFlowCore", "AxonFlowUI"]
        )
    ]
)
