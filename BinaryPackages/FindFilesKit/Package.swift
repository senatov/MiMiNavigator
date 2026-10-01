// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FindFilesKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "FindFilesKit", targets: ["FindFilesKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit"), .package(path: "../ExternalToolsKit")],
    targets: [
        .binaryTarget(name: "FindFilesKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-20351929fcfd1e2a/FindFilesKit.xcframework.zip", checksum: "90cd0d5ae7f3a038ec9465e22871b2aaeb2f5863c14016647894cd652b3aa46b"),
        .target(name: "FindFilesKitDependencies", dependencies: ["FindFilesKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit"), .product(name: "ExternalToolsKit", package: "ExternalToolsKit")])
    ]
)
