// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FEAViewer",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/LasCondes/AxiSymFEA.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "FEAViewer",
            dependencies: [
                .product(name: "AxiSymFEA", package: "AxiSymFEA")
            ],
            resources: [
                .copy("../../Resources")
            ]
        ),
    ]
)
