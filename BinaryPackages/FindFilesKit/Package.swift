// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "FindFilesKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "FindFilesKit", targets: ["FindFilesKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit"), .package(path: "../ExternalToolsKit")],
    targets: [
        .binaryTarget(name: "FindFilesKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-71ec12fc231c10ae/FindFilesKit.xcframework.zip", checksum: "8a24f5786ffd60c699aca0a359507183c30c34c31e6ab76e5daa6a0f7c753487"),
        .target(name: "FindFilesKitDependencies", dependencies: ["FindFilesKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit"), .product(name: "ExternalToolsKit", package: "ExternalToolsKit")])
    ]
)
