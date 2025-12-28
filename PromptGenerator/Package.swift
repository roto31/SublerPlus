// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PromptGenerator",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "PromptGenerator",
            targets: ["PromptGenerator"]
        )
    ],
    targets: [
        .executableTarget(
            name: "PromptGenerator",
            dependencies: [],
            path: ".",
            sources: [
                "PromptGeneratorApp.swift",
                "ContentView.swift",
                "PromptGeneratorViewModel.swift"
            ]
        )
    ]
)

