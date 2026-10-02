// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Slashlate",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Slashlate", targets: ["Slashlate"])
    ],
    targets: [
        .executableTarget(
            name: "Slashlate",
            path: "Sources/Slashlate"
        ),
        .testTarget(
            name: "SlashlateTests",
            dependencies: ["Slashlate"],
            path: "Tests/SlashlateTests"
        )
    ]
)
