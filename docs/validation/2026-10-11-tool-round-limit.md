# 自动工具调用上限调整

- 将 AgentHost 默认上限与 Resources 预算从 8 同步为 50；每条任务独立计数，每次工具调用计为一轮，第 51 次仍被拒绝。
- 同步已有预算测试、Agent Runtime 文档及中英文 README。

## 验证

- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：退出码 0，全部通过，包括现有工具上限测试和预算测试。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：`BUILD SUCCEEDED`。
- 未执行真实模型的 50 次工具调用，也未重启正在运行的应用；新上限需要运行本次构建的应用。
- README 已同步中英文上限说明；AGENTS.md 无开发命令或架构边界变更，保持不变。构建产物沿用现有忽略规则。
