# 搜索结果分组标题字号

- 分组标题统一为 14 pt、`.regular`（400）字重，对应用户要求的 14px 样式。
- 修改位置：`App/Sources/LauncherView.swift` 的结果分组标题。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 `Packages/KulaCore`）：128 tests / 27 suites 通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- 未进行实际窗口视觉验证，未重启正在运行的应用。
- README 与 AGENTS.md 无需修改：仅调整现有标题样式，无命令、使用流程或架构变化。
