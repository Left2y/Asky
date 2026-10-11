# 设置页滚动与标题重叠修复

- 原因：全高度设置窗口中的 SwiftUI Form 仅对内容应用安全区，滚动视口仍延伸到透明工具栏后方，内容可穿过固定页面标题。
- 修复：右侧使用 AppKit 容器，将 SwiftUI hosting view 的四边约束至容器安全区，并裁剪 hosting view。保留原生全高度侧边栏、工具栏和窗口尺寸约束。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 `Packages/KulaCore`）：通过，Swift Testing 共 19 项。
- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过。
- `python3 App/Tests/run-settings-regression.py`：通过。检查全部 9 个页面的深浅主题与最小窗口尺寸，断言右侧视口不进入工具栏区域；数据来源页通过原生 NSScrollView 滚到底部并生成深浅主题截图。
- 使用 computer-use 查看实际 SettingsWindow 的可见原生窗口：数据来源页标题与表单分离；检查滚动截图，内容裁剪于工具栏下方。
- GUI 工具的滚轮调用未改变滚动位置，因此滚动结论来自原生 NSScrollView 回归和截图，不计 GUI 调用为成功。AppKit 缓存截图不含工具栏文字与侧边栏完整合成，工具栏位置另由布局断言和可见窗口检查确认。
- 构建、回归 bundle 和截图沿用 `.gitignore` 的 `build/` 规则。未打包 Release、未安装到 Applications。
- README: unchanged；这是布局缺陷修复，不改变使用方式或开发命令。AGENTS.md: unchanged；无新命令、模块边界或持久规则。
