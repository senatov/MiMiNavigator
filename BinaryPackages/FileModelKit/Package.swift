// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "FileModelKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "FileModelKit", targets: ["FileModelKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "FileModelKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-088574402e51daba/FileModelKit.xcframework.zip", checksum: "b9a29bd894a66cee0d58374ca55b45d663e768501e460b9213c1795e7998c126"),
        .target(name: "FileModelKitDependencies", dependencies: ["FileModelKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
