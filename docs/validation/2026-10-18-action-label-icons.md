# 搜索与剪贴板列表操作文字

搜索底部左侧主操作与「在访达中显示」、剪贴板列表底部左侧操作去掉文字前图标，保留标题、快捷键与按钮行为；更多菜单内图标保留。

实际执行：

- `xcodegen generate`：通过。
- README 中 Debug `xcodebuild` 命令：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，37 tests / 9 suites。
- `run-launcher-window-regression.py --action-bar`：已生成实际搜索窗口截图，确认左侧「打开」「在访达中显示」只有文字和快捷键。完整回归未通过：`selected text must fall through to native Copy`；单独重跑二进制时 `file primary action must be Open` 断言失败。
- `run-clipboard-regression.py --layouts`：未通过，现有第 397 行仍断言旧配置默认 `.cards`，与当前默认列表不符。
- 已编译剪贴板回归二进制 `build/ClipboardRegression.app/Contents/MacOS/ClipboardRegression --floating-actions`：进程通过并生成浅色、深色截图；截图检查发现搜索框收到桌面输入，变为无匹配内容，不能作为剪贴板操作按钮视觉验收通过的证据。剪贴板按钮移除由代码与构建确认。
- `git diff --check`：通过。

截图位于忽略的 `build/`：`launcher-actions-NSAppearanceNameAqua-closed.png`、`clipboard-floating-light-top.png`、`clipboard-floating-dark-top.png`。

README 无需修改：仅调整操作按钮视觉细节，使用方式和命令不变。AGENTS.md 无需修改：未改变架构、开发流程或指令边界；设计规范已同步。
