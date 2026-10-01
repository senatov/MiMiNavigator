// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ScannerKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "ScannerKit", targets: ["ScannerKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "ScannerKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-20351929fcfd1e2a/ScannerKit.xcframework.zip", checksum: "cc1041e80474cea6b96eee0337cc438e676806d7fcc9901a7ea5bdc6a95f98f8"),
        .target(name: "ScannerKitDependencies", dependencies: ["ScannerKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
