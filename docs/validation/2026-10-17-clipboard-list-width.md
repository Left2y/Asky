# 剪贴板列表宽度调整

列表模式窗口从 900 × 560 pt 调整为 720 × 560 pt，左侧历史列表从 340 pt 等比缩为 272 pt，分隔线保持 1 pt，右侧为 447 pt。卡片模式维持 900 × 244 pt。首次打开与切换布局均使用对应宽度。

实际执行：

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts`：通过，覆盖布局切换、设置持久化、选中项保留、搜索、固定和复制。
- 查看新生成的 `build/clipboard-layout-list-text.png`：Retina 图片为 1440 × 1120 px（720 × 560 pt），分隔线位于 272 pt，右侧信息未被截断。

构建及截图产物沿用现有 `build/` 忽略规则。README 中英文同步尺寸；AGENTS.md 无需调整，本次未改变开发命令或模块边界。
