// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RenameKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "RenameKit", targets: ["RenameKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "RenameKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-ffba754c7dd76553/RenameKit.xcframework.zip", checksum: "8d27f1f7cd5721ce52315bbd5b2925e6ab02e0995f42f72b1a2e45fd979c55e9"),
        .target(name: "RenameKitDependencies", dependencies: ["RenameKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
