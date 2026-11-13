// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RenameKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "RenameKit", targets: ["RenameKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "RenameKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-71ec12fc231c10ae/RenameKit.xcframework.zip", checksum: "22e8fd5eb96f6410d49443316b5068fd2bc48b61ace020f17614553b64239cb4"),
        .target(name: "RenameKitDependencies", dependencies: ["RenameKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
