// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PythonTools",
    platforms: [.macOS(.v14), .iOS(.v17), .visionOS(.v1)],
    products: [
        .library(name: "PythonTools",
                 targets: ["PythonTools"]),
    ],
    dependencies: [
        .package(url: "https://github.com/wabiverse/MetaversePythonFramework.git", from: "3.11.7"),
    ],
    targets: [
        .target(name: "PythonTools",
                dependencies: [
                    .product(name: "Python", package: "MetaversePythonFramework")
                ]),
        .testTarget(
            name: "PythonToolsTests",
            dependencies: ["PythonTools"]
        ),
    ]
)
