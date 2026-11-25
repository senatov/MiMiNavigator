// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ScannerKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "ScannerKit", targets: ["ScannerKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "ScannerKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-088574402e51daba/ScannerKit.xcframework.zip", checksum: "cd30a7b1211177c7104589eef72fd2e9f7e5213ea320f51a0cf8c86d4201b509"),
        .target(name: "ScannerKitDependencies", dependencies: ["ScannerKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
