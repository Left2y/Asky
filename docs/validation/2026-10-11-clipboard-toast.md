# 剪贴板状态提示样式

- 范围：仅剪贴板底部状态 toast 的视觉样式。复制、错误提示与窗口行为沿用现有逻辑。
- 新样式：14pt Regular 文字、12pt 连续圆角、16/9pt 内距、距底边 12pt；复制成功显示 12pt 勾选图标。使用不透明语义背景、1pt 语义描边及轻阴影，避免卡片颜色穿透提示。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：本次运行失败，EventStoreAccessTests.swift 的 `#expect(state.observe(...))` 展开后无法对不可变参数调用 mutating 方法。此文件属于本次任务之外的并行修改，未修改或计为通过。
- 原生检查：使用现有 ClipboardRegression 的独立临时副本和测试数据显示真实剪贴板 NSPanel，调用 copySelection 显示 toast，通过 Orca 捕获窗口检查最终深色版本：勾选图标与文字对齐、底部留白完整、背景不透出蓝色图片。浅色模式与长错误文本未作实际窗口验收。
- README: unchanged；这是局部视觉修正，不改变使用方法或开发命令。
- AGENTS.md: unchanged；没有新增命令或架构边界。
