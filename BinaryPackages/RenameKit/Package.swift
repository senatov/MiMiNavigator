// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RenameKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "RenameKit", targets: ["RenameKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "RenameKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-3f53511a20cf81ff/RenameKit.xcframework.zip", checksum: "21e8129b4463523dfc2e62ec5758eab7e763e650404ef44e135255ad2d96bbd2"),
        .target(name: "RenameKitDependencies", dependencies: ["RenameKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
