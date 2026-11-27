// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RenameKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "RenameKit", targets: ["RenameKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "RenameKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-620c6f4696b40b67/RenameKit.xcframework.zip", checksum: "d87c291680a5917a9312303f4cc5048278361e95abffcf2c42612c13ed63c628"),
        .target(name: "RenameKitDependencies", dependencies: ["RenameKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
