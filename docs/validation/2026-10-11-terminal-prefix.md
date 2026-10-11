# 英文 > 终端入口验证

日期：2026-10-11

## 行为

- 英文 `>`（无需空格）进入终端作用域；显示终端图标，输入框只保留命令正文。
- 空命令无结果、不会执行；空输入框退格退出，粘贴 `>pwd` 也能识别。
- 回车经过 ToolService 向 macOS Terminal 发送命令，使用配置的工作目录；成功隐藏启动器，失败保留错误提示。
- 工作目录进行 Shell 引号转义，完整命令作为 AppleScript 字符串转义；不改写用户的重定向、引号等 Shell 语法。

## 已运行检查

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，包含前缀、正文中的 `>`、退格、模式切换及脚本编译/转义检查。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/run-launcher-terminal-regression.py --handoff`：通过。实际新建原生启动器窗口，检查 NSTextField 正文与结果；经 `LauncherModel.submit(.executeSelection)` 提交测试命令，Terminal 在临时工作目录写入 `handoff.txt`，回读内容为 `terminal-ok`，确认启动器隐藏且没有面板内 Shell 会话。
- 已查看 `build/launcher-terminal.png`：终端图标、命令正文与“在终端中运行”结果显示正常；图片是原生视图缓存，不作为桌面背景合成验收。
- `git diff --check`：通过。

## 验证范围

测试运行器在当前环境中的 Terminal Apple Events 执行成功；首次安装的自动化授权弹窗、拒绝后恢复，以及正式 App 身份的权限归属尚未单独验收。未打包 Release 或安装到本地应用目录。

README 中英文使用说明与回归命令已同步；AGENTS.md 无新增持久指导需求。构建、图片和生成工程沿用现有忽略规则。
