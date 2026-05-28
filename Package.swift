// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Mdora",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Mdora", targets: ["Mdora"]),
        .executable(name: "MdoraParserTest", targets: ["MdoraParserTest"])
    ],
    targets: [
        .target(name: "MdoraCore"),
        .executableTarget(
            name: "Mdora",
            dependencies: ["MdoraCore"]
        ),
        .executableTarget(
            name: "MdoraParserTest",
            dependencies: ["MdoraCore"]
        )
    ]
)
