// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RenameKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "RenameKit", targets: ["RenameKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "RenameKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-20351929fcfd1e2a/RenameKit.xcframework.zip", checksum: "949687b0536dfbddf32d886b3080fe2690f242a452f4a382358f466e2f55a861"),
        .target(name: "RenameKitDependencies", dependencies: ["RenameKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
