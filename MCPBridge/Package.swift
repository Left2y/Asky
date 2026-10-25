// swift-tools-version: 6.2
import PackageDescription

// No third-party dependencies: the MCP stdio protocol subset lives in KulaCore/MCPLink (MCPStdioServer).
let package = Package(
    name: "MCPBridge",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "asky-mcp", targets: ["asky-mcp"])],
    dependencies: [
        .package(path: "../Packages/KulaCore"),
    ],
    targets: [
        .executableTarget(name: "asky-mcp", dependencies: [
            .product(name: "MCPLink", package: "KulaCore"),
            .product(name: "Contracts", package: "KulaCore"),
        ]),
    ],
    swiftLanguageModes: [.v6]
)
