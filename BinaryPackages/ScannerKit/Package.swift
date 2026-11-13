// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ScannerKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "ScannerKit", targets: ["ScannerKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "ScannerKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-71ec12fc231c10ae/ScannerKit.xcframework.zip", checksum: "0b4bd1e74a85962d46fcc634b0ed066903c0539c371df8b6e0d557c587cf7b1a"),
        .target(name: "ScannerKitDependencies", dependencies: ["ScannerKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
