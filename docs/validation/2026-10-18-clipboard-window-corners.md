# 剪贴板主窗口圆角统一

- 剪贴板主窗口复用 `LauncherLayout.shellCornerRadius`，当前为输入区高度 52 pt 的一半，即 26 pt；卡片与列表共用该外壳。
- SwiftUI 背景及裁剪采用 `.circular`，AppKit 玻璃、内容和窗口框架层通过 `WindowSurface.updateCorners` 同步，保持原生系统阴影。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：37 项 Swift Testing 测试通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --floating-actions`：通过；检查新编译原生窗口的浅色、深色截图，四角裁剪完整，未见方角黑边。截图位于被忽略的 `build/clipboard-floating-{light,dark}-top.png`。此项只用于本次外壳圆角检查，不作为列表交互验收。

README 无需变更：仅调整外壳圆角，使用方式与开发命令不变。AGENTS.md 无需变更：现有玻璃窗口规范和验证命令仍适用。
