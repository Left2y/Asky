# 剪贴板默认列表式

- `SettingsPreferences.clipboardLayout` 默认值由 `.cards` 改为 `.list`。配置解码继续保留已保存的样式，缺少字段时采用新默认值。
- README 中英文同步说明默认样式及已有选择的保留行为。

## 已运行验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过，`BUILD SUCCEEDED`。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- 将实际 `App/Sources/SettingsPreferences.swift` 与临时检查入口编译运行：新建配置与缺少 `clipboardLayout` 的配置均为 `.list`；已保存的 `cards`、`list` 均保持原值。临时入口、二进制和日志在已忽略的 `build/` 中。

本次只更改配置默认值，未运行实际窗口视觉验收。工作区已有的剪贴板窗口、回归和粘贴目标改动未纳入本次提交。

## 文档检查

- README：更新中英文默认样式说明。
- AGENTS.md：保持不变；未引入命令、架构或开发流程变化。
