// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LogKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "LogKit", targets: ["LogKitDependencies"])],
    dependencies: [.package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver", exact: "2.1.1")],
    targets: [
        .binaryTarget(name: "LogKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-ffba754c7dd76553/LogKit.xcframework.zip", checksum: "7cdea662fda2d97e6f94550f25712da5968e1d6385f14dbf854998c2d6fb399c"),
        .target(name: "LogKitDependencies", dependencies: ["LogKit", .product(name: "SwiftyBeaver", package: "SwiftyBeaver")])
    ]
)
