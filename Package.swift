// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EmailNotebookLMIntegration",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "EmailNotebookLMIntegration", targets: ["EmailNotebookLMIntegration"])
    ],
    targets: [
        .executableTarget(name: "EmailNotebookLMIntegration")
    ]
)