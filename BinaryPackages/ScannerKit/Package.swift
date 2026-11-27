// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ScannerKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "ScannerKit", targets: ["ScannerKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "ScannerKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-620c6f4696b40b67/ScannerKit.xcframework.zip", checksum: "fd5204f113ab3a398e2f50863f9ca28c5e1e59b155bce64c6fdf5757a0d359d2"),
        .target(name: "ScannerKitDependencies", dependencies: ["ScannerKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
