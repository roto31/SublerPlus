// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SublerPlus",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "SublerPlusCore", targets: ["SublerPlusCore"]),
        .executable(name: "SublerPlusApp", targets: ["SublerPlusApp"]),
        .executable(name: "SublerPlusCLI", targets: ["SublerPlusCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/httpswift/swifter.git", from: "1.5.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.6.4")
    ],
    targets: [
        .target(
            name: "SublerPlusCore",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "Swifter", package: "swifter")
            ],
            path: "App",
            exclude: [
                "Main.swift",
                "AppDelegate.swift",
                "Views"
            ],
            resources: []
        ),
        .executableTarget(
            name: "SublerPlusApp",
            dependencies: [
                "SublerPlusCore",
                .product(name: "Swifter", package: "swifter"),
                .product(name: "Alamofire", package: "Alamofire")
            ],
            path: "App",
            exclude: [
                "Controllers",
                "Models",
                "Resources"
            ],
            sources: [
                "Main.swift",
                "AppDelegate.swift",
                "Views"
            ],
            resources: [
                .process("../WebUI/Views"),
                .process("../WebUI/Assets"),
                .process("../Resources")
            ]
        ),
        .executableTarget(
            name: "SublerPlusCLI",
            dependencies: [
                "SublerPlusCore"
            ],
            path: "CLI"
        ),
        .testTarget(
            name: "SublerPlusCoreTests",
            dependencies: ["SublerPlusCore"],
            path: "Tests"
        )
    ]
)

