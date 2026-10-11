# 英文 > 终端入口验证

日期：2026-10-11

## 行为

- 英文 `>`（无需空格）进入终端作用域；显示所选终端应用的真实图标（默认系统终端），输入框只保留命令正文。
- 空命令无结果、不会执行；空输入框退格退出，粘贴 `>pwd` 也能识别。
- 回车经过 ToolService 向设置中选择的终端发送命令，使用配置的工作目录；成功隐藏启动器，失败保留错误提示。
- “设置 › 通用 › 终端 › 执行命令的终端”列出已安装的系统终端、iTerm2 与 Ghostty（1.3+）；选择保存于 AppSettings。旧版设置缺少可选的 terminalApplicationID 字段时正常读取，不重置已有配置；已配置终端卸载后报错而不改用其他终端。
- 工作目录进行 Shell 引号转义，完整命令作为 AppleScript 字符串转义；不改写用户的重定向、引号等 Shell 语法。

## 已运行检查

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，包含前缀、正文中的 `>`、退格、模式切换、脚本编译/转义、第三方派发和终端未安装时拒绝交接检查。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/run-launcher-terminal-regression.py --handoff`：通过。实际新建原生启动器与设置窗口，检查 NSTextField 正文、系统终端 Logo、选项持久化和旧设置解码；经 `LauncherModel.submit(.executeSelection)` 提交测试命令，Terminal 在临时工作目录写入 `handoff.txt`，回读内容为 `terminal-ok`，确认启动器隐藏且没有面板内 Shell 会话。
- 已查看 `build/launcher-terminal.png`：系统终端真实图标、命令正文与“在终端中运行”结果显示正常；同时查看 `build/terminal-settings.png`，执行命令的终端选项与系统终端 Logo 显示正常；图片是原生视图缓存，不作为桌面背景合成验收。
- `git diff --check`：通过。

## 验证范围

本机只安装系统终端，iTerm2 与 Ghostty 的原生派发脚本根据官方接口实现并做源码构造测试，未做第三方实际窗口执行验收。测试运行器在当前环境中的 Terminal Apple Events 执行成功；首次安装的自动化授权弹窗、拒绝后恢复，以及正式 App 身份的权限归属尚未单独验收。未打包 Release 或安装到本地应用目录。

README 中英文使用说明与回归命令已同步；AGENTS.md 无新增持久指导需求。构建、图片和生成工程沿用现有忽略规则。

## 第三方接口依据

- [iTerm2 AppleScript](https://iterm2.com/documentation-scripting.html)：创建默认 profile 窗口，向其 session 写入命令。
- [Ghostty AppleScript](https://ghostty.org/docs/features/applescript)：1.3.0 起提供原生字典，使用 surface configuration 的 initial working directory 与 initial input 创建窗口。
