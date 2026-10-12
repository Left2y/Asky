# 设置侧栏图标尺寸

- 彩色底板由 22 × 22 pt 调整为 18 × 18 pt，圆角由 7 pt 调整为 5 pt。
- SF Symbol 使用等比缩放，限制在 11 × 11 pt 内，避免原生 sidebar Label 的符号样式撑满底板。
- 外层仍占 22 × 22 pt，保留文字位置、行高、选择背景与导航行为。

## 实际验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，Swift Testing 23 项测试；默认 Command Line Tools 下首次运行因缺少 Testing 模块失败，指定 Xcode 后通过。
- 重启 `build/DerivedData/Build/Products/Debug/Asky.app`，通过该完整路径绑定新构建窗口，按 Command-comma 打开设置，检查真实窗口截图：12 项侧栏图标均缩小且符号四周留白清晰。
- README 与 AGENTS.md 无需调整：本次只修改图标比例，不改变开发流程、功能或模块边界。
- 工作区已有智能提醒相关改动；本次提交仅包含 SettingsWindow.swift 和本验证记录。
