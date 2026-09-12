// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ScannerKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "ScannerKit", targets: ["ScannerKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "ScannerKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-ffba754c7dd76553/ScannerKit.xcframework.zip", checksum: "f0401635fc85a4ec98f6d80bd0f6023eb1ed92d9374bf57656ceb9569fd1d3b8"),
        .target(name: "ScannerKitDependencies", dependencies: ["ScannerKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
