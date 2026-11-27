// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "FindFilesKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "FindFilesKit", targets: ["FindFilesKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit"), .package(path: "../ExternalToolsKit")],
    targets: [
        .binaryTarget(name: "FindFilesKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-620c6f4696b40b67/FindFilesKit.xcframework.zip", checksum: "07a16cbdb00e91a291ffe4c78993cd3aa5adc11aa8c73326240fbae852f5c70d"),
        .target(name: "FindFilesKitDependencies", dependencies: ["FindFilesKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit"), .product(name: "ExternalToolsKit", package: "ExternalToolsKit")])
    ]
)
