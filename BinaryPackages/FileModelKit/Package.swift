// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FileModelKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "FileModelKit", targets: ["FileModelKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "FileModelKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-ffba754c7dd76553/FileModelKit.xcframework.zip", checksum: "8020bef6cbd272b8c78e69adf02c72acaa561d0753f1ef16f4e185c5973032b7"),
        .target(name: "FileModelKitDependencies", dependencies: ["FileModelKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
