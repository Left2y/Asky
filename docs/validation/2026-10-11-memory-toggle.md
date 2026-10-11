# 记忆开关语义修正

- 设置 › 记忆中的开关改为“开启记忆”，打开表示允许提炼，关闭表示暂停提炼。
- 使用反向 Binding 对接已有 `memoryExtractionPaused` 设置；保留持久化字段和已有用户选择。默认 `false` 对应界面开启。AgentModel 的提炼入队条件仍为 `!memoryExtractionPaused`。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：通过。Xcode 输出已有的 CoreDevice/CoreSimulator 版本警告，macOS 构建成功。
- `python3 App/Tests/run-settings-regression.py`：原生浅色、深色设置快照检查通过。
- 新启动 `SettingsRegression.app --preview`，使用临时 LocalStore 运行实际 SettingsWindow。通过原生 UI 点击“记忆”，确认“开启记忆”默认为 on，点击后为 off，再点击恢复 on；检查真实窗口截图。
- 未调用模型验证实际提炼结果；本次修改仅涉及开关显示和绑定。
- README 与 AGENTS.md 无需调整：使用方式、开发命令和架构边界未变。
