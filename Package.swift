// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Curtain",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Curtain", targets: ["Curtain"])],
    targets: [
        // Pure logic: the curtain's phases, the wake key, the options and the restore record.
        // No AppKit, so it is fully unit-tested.
        .target(name: "CurtainCore"),
        .executableTarget(name: "Curtain", dependencies: ["CurtainCore"], linkerSettings: [
            .linkedFramework("AppKit"), .linkedFramework("Carbon"),
            .linkedFramework("IOKit"), .linkedFramework("ServiceManagement")
        ]),
        .testTarget(name: "CurtainCoreTests", dependencies: ["CurtainCore"])
    ]
)
