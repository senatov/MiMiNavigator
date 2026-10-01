// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FileModelKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "FileModelKit", targets: ["FileModelKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "FileModelKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-20351929fcfd1e2a/FileModelKit.xcframework.zip", checksum: "124770a2e056a9d4e91629b94c7c0d767c427bbb2fafdbc3019057b94188c1d3"),
        .target(name: "FileModelKitDependencies", dependencies: ["FileModelKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
