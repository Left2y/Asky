# MCP 配置操作按钮同行布局

- 原因：SettingsForm 将 Section 的每个直接子视图作为独立行，并添加分隔线；两个独立按钮因此显示成两行。
- 修改：将“复制配置”和“我已保存”放入同一个 HStack，左对齐，间距 12 点。
- `xcodegen generate`：通过。
- README 的 Debug `xcodebuild` 命令：通过，输出 `BUILD SUCCEEDED`。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `python3 App/Tests/run-settings-regression.py --preview` 编译并启动新 SettingsRegression.app，PID 48795，可执行文件为当前工作区 `build/SettingsRegression.app/Contents/MacOS/SettingsRegression`。使用临时 LocalStore，通过 Orca 操作真实深色 SettingsWindow 的外部 MCP 页面，创建临时实例后确认两个按钮同行，且两者之间没有分隔线；点击“我已保存”后配置区域消失。
- 本次未替换 /Applications 中的应用，也未验证浅色窗口或复制到剪贴板的内容。
- README 与 AGENTS.md 无需修改：仅调整既有按钮布局，命令、使用流程与架构边界未变。构建与预览产物沿用已有 `build/` 忽略规则。
