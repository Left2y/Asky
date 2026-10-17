# 仓库按钮去掉图标

- 移除 `StarRepositoryRow` 操作按钮的 `arrow.up.right` 图标，使用已有纯文字按钮样式。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- 启动本次 Debug 构建，打开“关于 Asky”，实际窗口确认“查看仓库”按钮仅显示文字、无箭头图标。
- README 与 AGENTS.md：无需更新；此次改动不影响使用流程、开发命令或架构约束。
