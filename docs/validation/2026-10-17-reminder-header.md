# 提醒卡片顶部精简

- 按截图移除顶部 `Asky ·` 应用名称前缀和 ⓘ 提醒原因按钮及其弹窗；保留图标、提醒类别（如有）、时间、正文及操作按钮。仅包含应用名称的来源不显示文本。
- 更新 PRD，移除提醒原因入口的旧要求；原因数据保留，不改变提醒生成及去重逻辑。
- 已执行 `xcodegen generate` 和 README 中 Debug `xcodebuild` 命令，结果 `BUILD SUCCEEDED`。
- 已运行 `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，退出码 1：`RealRuntimeIntegrationTests.unreachableModelFailsAndProcessIsGone` 在第 37、39 行失败，实际状态为 starting → failed，未取得 runningPID。本次未修改该测试或 AgentHost，不将全量测试记为通过。
- 启动新构建 `Asky --test-banner`，通过 Orca computer-use 读取该进程的真实窗口并检查截图：顶部仅有应用图标、“情境提醒”和“15 分钟后”，无应用名称前缀和信息按钮；正文与两个操作按钮布局正常。截图位于已忽略的 `build/reminder-header/preview.png`。
- 未执行操作按钮点击及多屏回归。
- README: unchanged：本次仅精简卡片辅助信息，不改变使用方式、构建命令或已描述能力。
- AGENTS.md: unchanged：未引入新的命令、模块边界或持久开发规则。
