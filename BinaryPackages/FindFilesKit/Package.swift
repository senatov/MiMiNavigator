// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FindFilesKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "FindFilesKit", targets: ["FindFilesKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit"), .package(path: "../ExternalToolsKit")],
    targets: [
        .binaryTarget(name: "FindFilesKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-ffba754c7dd76553/FindFilesKit.xcframework.zip", checksum: "e55717d7b41f0c5bd20f71ea3c3734756bc04326e2ac38580574927f6b62cbfc"),
        .target(name: "FindFilesKitDependencies", dependencies: ["FindFilesKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit"), .product(name: "ExternalToolsKit", package: "ExternalToolsKit")])
    ]
)
