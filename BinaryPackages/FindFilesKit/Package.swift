// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "FindFilesKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "FindFilesKit", targets: ["FindFilesKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit"), .package(path: "../ExternalToolsKit")],
    targets: [
        .binaryTarget(name: "FindFilesKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-088574402e51daba/FindFilesKit.xcframework.zip", checksum: "f7fd81e0a8fa2f388c17989588a73c35877b112188279eff6e4541dd882efeac"),
        .target(name: "FindFilesKitDependencies", dependencies: ["FindFilesKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit"), .product(name: "ExternalToolsKit", package: "ExternalToolsKit")])
    ]
)
