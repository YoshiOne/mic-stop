// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MicStop",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "MicStopApp", targets: ["MicStopApp"])
    ],
    targets: [
        .executableTarget(
            name: "MicStopApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .testTarget(
            name: "MicStopAppTests",
            dependencies: ["MicStopApp"]
        )
    ]
)
