// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RenameKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "RenameKit", targets: ["RenameKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "RenameKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-088574402e51daba/RenameKit.xcframework.zip", checksum: "5aa4f83eb0cb58f4434478369dbfaa454d03e653b5a98f1fa362c7bf594d0382"),
        .target(name: "RenameKitDependencies", dependencies: ["RenameKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
