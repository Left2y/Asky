# 删除模型预设的两行辅助内容

日期：2026-10-13。

按截图删除所有服务商预设中的“获取 API Key”链接与接口说明行，包括 Qwen 的地域专用说明，并删除对应中英文资源。预设共用同一视图分支。

实际执行：
- `xcodegen generate` 通过。
- README 的 Debug `xcodebuild` 通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 通过（36 个 Swift Testing 测试；其他 XCTest 结果见本次日志）。
- 两个 Localizable.strings 的 `plutil -lint` 与 `git diff --check` 通过。
- `python3 App/Tests/run-settings-regression.py --preview` 编译并启动本次源码的原生设置预览（PID 4246，build/SettingsRegression.app/Contents/MacOS/SettingsRegression）。通过 computer-use 打开模型设置，DeepSeek 暗色窗口截图与可访问树确认 API 地址直接接 API Key，已无这两行。其他预设由共用分支源码确认，未逐一截图。此预览不是完整设置回归通过，也不是已安装应用验收。

构建与测试日志：`/tmp/asky-remove-provider-rows-build.log`、`/tmp/asky-remove-provider-rows-tests.log`。
窗口截图保存于 `build/remove-model-provider-extra-rows-dark.png`（复用 build/ 忽略规则）。

README: unchanged — 删除辅助行不改变配置操作或开发命令。
AGENTS.md: unchanged — 未改变模块边界、子项目或持久开发规则。

Git：这些辅助行来自任务开始前尚未提交的模型预设实现，在 HEAD 中不存在。本次删除无法作为独立源码提交表达而不包含既有功能改动，因此不提交混合改动，保留已有工作区与索引。
