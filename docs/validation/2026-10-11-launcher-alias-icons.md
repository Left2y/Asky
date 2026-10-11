# 应用别名图标修复验证

截图中的 `codex → ChatGPT` 是应用别名。别名结果使用 `.keyword` 来源及 `.open` 动作，原图标分支只识别网页 `.openURL`，因此错误回退到地球图标。

修复：应用别名通过 ToolService 读取目标文件图标；快捷指令别名使用与快捷指令结果相同的符号。网页和书签图标规则保持不变。

实际执行：

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：通过。
- `xcodegen generate`：通过。
- README 中 Asky Debug `xcodebuild` 命令：通过，日志 `build/alias-icon-build.log`。
- 临时原生窗口 harness，复用真实 LauncherModel、LauncherView、LauncherController 与 Debug 模块；隔离 AppModel 数据，配置 `codex → /Applications/ChatGPT.app` 与快捷指令别名 `sc → Daily`：浅色、深色执行通过，并人工检查实际窗口截图，ChatGPT 原生图标及快捷指令符号正确。

窗口截图位于 `build/alias-icon-{codex,sc}-{NSAppearanceNameAqua,NSAppearanceNameDarkAqua}.png`；日志 `build/alias-icon-regression.log`。临时 harness 位于 `/tmp/AskyAliasIconRegression.swift` 和 `/tmp/run-asky-alias-icons.py`，不是长期测试入口。初次编译因继承 SDKROOT 不匹配、缺少 SettingsPage 声明失败，临时 harness 修正后运行成功；期间焦点/输入法导致别名断言失败，最终运行通过。该验证不涵盖键盘输入法行为。

未打包或安装 Release。README 与 AGENTS.md 的使用命令、模块边界无需变化。
