// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "FileModelKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "FileModelKit", targets: ["FileModelKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "FileModelKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-620c6f4696b40b67/FileModelKit.xcframework.zip", checksum: "2fab409675f34c6ecec673a40de456f15ac07605305aab89277372b835c183d0"),
        .target(name: "FileModelKitDependencies", dependencies: ["FileModelKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
