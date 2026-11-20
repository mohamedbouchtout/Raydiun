// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RaydiunDomain",
    platforms: [.macOS(.v14), .iOS(.v17), .watchOS(.v10)],
    products: [.library(name: "RaydiunDomain", targets: ["RaydiunDomain"])],
    targets: [
        .target(name: "RaydiunDomain", path: "Shared/Domain"),
        .testTarget(name: "DomainTests", dependencies: ["RaydiunDomain"], path: "Tests/DomainTests")
    ]
)
