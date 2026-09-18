// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuranApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "QuranApp",
            targets: ["QuranApp"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0")
    ],
    targets: [
        .target(
            name: "QuranApp",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "QuranApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "QuranAppTests",
            dependencies: ["QuranApp"],
            path: "Tests"
        )
    ]
)
