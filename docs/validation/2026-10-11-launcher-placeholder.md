# 启动器空输入提示

- 空输入时使用本地化占位文字：中文“搜索或输入你的任务”，英文“Search or input your task”。不以焦点状态隐藏提示；输入后由原生 NSTextField 隐藏占位文字。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 `Packages/KulaCore`）：通过。
- `xcodegen generate` 与 README 中的 Debug `xcodebuild` 命令：通过。
- README 中的 `LauncherSearchFieldRegression` 编译和运行命令：通过。
- 重启 Debug 应用后，实际窗口截图和辅助功能树确认：聚焦的空输入框显示中文占位文字；输入 `Safari` 后只显示输入内容；重新打开空输入窗口恢复占位文字。
- 英文文案已进入本地化资源并通过构建；本次实际窗口检查使用中文环境。
- README: unchanged，微小提示文案修复不影响使用步骤或命令。AGENTS.md: unchanged，没有新增持久开发规则。
