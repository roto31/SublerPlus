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
        .executable(name: "SublerPlusCLI", targets: ["SublerPlusCLI"]),
        .executable(name: "MCPServerExecutable", targets: ["MCPServerExecutable"])
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
                "Views",
                "SublerPlus.entitlements",
                "Resources/AppIcon.appiconset",
                "Controllers/SublerCompatibility/ProviderPriority.swift" // Duplicate - using main one
                // Note: SublerCompatibility is included but uses #if canImport(MP42Foundation)
                // The framework must be built using scripts/build-with-subler.sh for these files to compile
            ],
            resources: []
        ),
        .target(
            name: "MCPServer",
            dependencies: [
                "SublerPlusCore"
            ],
            path: "MCPServer",
            exclude: ["main.swift"]
        ),
        .executableTarget(
            name: "MCPServerExecutable",
            dependencies: [
                "SublerPlusCore",
                "MCPServer"
            ],
            path: "MCPServer",
            sources: ["main.swift"]
        ),
        .executableTarget(
            name: "SublerPlusApp",
            dependencies: [
                "SublerPlusCore",
                "MCPServer",
                .product(name: "Swifter", package: "swifter"),
                .product(name: "Alamofire", package: "Alamofire")
            ],
            path: "App",
            exclude: [
                "Controllers",
                "Models",
                "SublerPlus.entitlements"
            ],
            sources: [
                "Main.swift",
                "AppDelegate.swift",
                "Views"
            ],
            resources: [
                .process("../WebUI/Views"),
                .process("../WebUI/Assets"),
                .process("../Resources"),
                .process("Resources")
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

