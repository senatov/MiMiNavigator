// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ScannerKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "ScannerKit", targets: ["ScannerKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "ScannerKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-3f53511a20cf81ff/ScannerKit.xcframework.zip", checksum: "7cc4d64c745b4572e17be041beca1ae4e9514cbc34fc206e5de1249db4680efb"),
        .target(name: "ScannerKitDependencies", dependencies: ["ScannerKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
