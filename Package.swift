// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PerfectFileMakerAdminAPI",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "PerfectFileMakerAdminAPI", targets: ["PerfectFileMakerAdminAPI"]),
    ],
    targets: [
        .target(name: "PerfectFileMakerAdminAPI"),
        .testTarget(name: "PerfectFileMakerAdminAPITests", dependencies: ["PerfectFileMakerAdminAPI"]),
    ]
)
