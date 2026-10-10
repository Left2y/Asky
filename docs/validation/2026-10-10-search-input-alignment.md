# 搜索输入前后位置统一

- 依据：用户提供的空输入与输入 `go` 截图，要求统一到有输入时的位置。
- 原因：左右内边距、输入高度、编辑器字号和放大镜占位尺寸随 `hasInput` 变化。
- 调整：统一为左右 28 pt 内边距、64 pt 输入高度、18 pt 字号、26 pt 编辑器高度、19 × 24 pt 图标占位；放大镜维持右侧。
- 已运行：`cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，128 tests / 27 suites 通过。
- 已运行：`xcodegen generate`，成功。
- 已运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`，BUILD SUCCEEDED。
- 未运行：原生窗口截图视觉验收。
- README 中英文同步尺寸与布局；AGENTS.md 无工作流或边界变化，保持不变。
