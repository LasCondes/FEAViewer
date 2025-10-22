// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PulleyViewer",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../PulleySwift"),
        .package(url: "https://github.com/LasCondes/AxiSymFEA.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "PulleyViewer",
            dependencies: [
                .product(name: "PulleyCore", package: "PulleySwift"),
                .product(name: "AxiSymFEA", package: "AxiSymFEA")
            ]
        ),
    ]
)
