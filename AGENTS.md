# Asky

Asky 是使用 SwiftUI 与 AppKit 构建的 macOS 原生效率入口。各目录的作用和开发命令见 [README](README.md)。

- 产品范围、用户流程和验收以 [V1 PRD](docs/PRD.md) 为准。涉及模块或进程边界时，先读[产品框架与架构大纲](docs/framework.md)，再通过[文档索引](docs/README.md)查阅对应专题。
- 所有系统读写只能经由 `Packages/KulaCore` 中的 ToolService。不要在 App、AgentRuntime 或 MCPBridge 中绕过它直接调用系统接口。
- 修改 Swift 代码后，运行 `cd Packages/KulaCore && swift test`；修改 AgentRuntime 后，运行 `npm test`；修改 App 后，用 `xcodegen generate` 生成工程，再用 `xcodebuild` 构建。如果 `xcode-select` 指向 Command Line Tools，命令前加 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`。
- 只有实际运行过的检查才能记为通过。验证结果写入 `docs/validation/`。开发命令必须来自实际配置，并同步到 README。
