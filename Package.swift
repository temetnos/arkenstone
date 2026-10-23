// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ArkenStone",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ArkenStone", targets: ["ArkenStone"])
    ],
    targets: [
        .executableTarget(
            name: "ArkenStone",
            path: "Sources/Arken"
        ),
    ]
)
