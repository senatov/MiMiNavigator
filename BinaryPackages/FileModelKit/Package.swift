// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "FileModelKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "FileModelKit", targets: ["FileModelKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "FileModelKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-3f53511a20cf81ff/FileModelKit.xcframework.zip", checksum: "97e4f3993ecba18a47f3c18b1168c44942a6f90fe66df7e78c51e7d4265c3777"),
        .target(name: "FileModelKitDependencies", dependencies: ["FileModelKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
