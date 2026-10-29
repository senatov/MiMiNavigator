// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ScannerKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "ScannerKit", targets: ["ScannerKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "ScannerKit", path: "ScannerKit.xcframework"),
        .target(name: "ScannerKitDependencies", dependencies: ["ScannerKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
