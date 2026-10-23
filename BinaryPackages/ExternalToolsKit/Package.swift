// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ExternalToolsKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "ExternalToolsKit", targets: ["ExternalToolsKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "ExternalToolsKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-3f53511a20cf81ff/ExternalToolsKit.xcframework.zip", checksum: "83351b0dd0f8d29473f2f1326d0215505a17ecf5c25ebc9f603186b42edda7a3"),
        .target(name: "ExternalToolsKitDependencies", dependencies: ["ExternalToolsKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
