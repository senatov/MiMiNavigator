// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FindFilesKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "FindFilesKit", targets: ["FindFilesKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit"), .package(path: "../ExternalToolsKit")],
    targets: [
        .binaryTarget(name: "FindFilesKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-3f53511a20cf81ff/FindFilesKit.xcframework.zip", checksum: "0ddace0c5deef1ec5dcfb697527378885123d98a8fa72cdff55346b851fbdedd"),
        .target(name: "FindFilesKitDependencies", dependencies: ["FindFilesKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit"), .product(name: "ExternalToolsKit", package: "ExternalToolsKit")])
    ]
)
