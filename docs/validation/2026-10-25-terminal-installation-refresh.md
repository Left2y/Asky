# 卸载终端后的设置列表刷新

## 问题与修复

终端设置通过 `@State` 保存已安装终端，但原先只在 `onAppear` 加载。用户在设置仍打开期间卸载 Ghostty 后，旧列表可能继续显示它。本机独立查询 `NSWorkspace.shared.urlForApplication` 时 Ghostty 与 iTerm2 均返回 nil，系统终端返回有效应用路径。

设置现在在应用重新激活、窗口重新获得键盘焦点时重新加载。ToolService 也验证注册路径存在、bundle ID 匹配且可执行文件仍可执行，拒绝已删除应用的旧路径。保留原有行为：若用户此前选中的终端被卸载，显示“（未安装）”，执行时报错，不擅自切换终端。

## 已执行检查

- `cd AgentRuntime && npm ci && npm run build`：通过，准备核心插件测试所需运行时。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，13 个测试运行合计 311 项。新增用例覆盖有效 Ghostty fixture、bundle ID 不符、可执行文件删除、整个应用删除及空注册路径。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/run-launcher-terminal-regression.py`：通过，覆盖旧设置解码、终端选择与持久化、图标、原生输入框终端前缀及退格交互；不覆盖 Finder 卸载后的焦点刷新流程。

日志位于忽略的 `build/ghostty-*.log`。未重新安装 Ghostty 后操作 Finder 卸载，焦点刷新未进行该完整人工流程验收；没有替换用户当前安装或发布新版。

## 文档与指令检查

- README 无需修改：修复已有终端安装检测，不改变使用方式或开发命令。
- AGENTS.md 无需修改：模块边界、子项目和持久开发规则未变。
