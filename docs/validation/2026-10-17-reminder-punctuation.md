# 提醒卡片中文结尾标点

- 提醒卡片所有可见文案在显示时移除末尾中文句号，保留句中标点；覆盖标题、正文、来源、时间和按钮标签，包括动态生成的提醒
- 同步 PRD 中的卡片文案规则
- 已执行 `xcodegen generate` 和 README 中 Debug `xcodebuild` 命令，结果 `BUILD SUCCEEDED`
- 已执行 `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，退出码 0，全量测试通过
- 使用新构建的 `Asky --test-banner` 并通过 Orca computer-use 检查实际窗口和可访问性树，会议提醒以“准备”结束、出行提醒以“拥堵”结束，均无句号，句中逗号保留
- 截图位于已忽略的 `build/reminder-punctuation/preview.png`，复用现有 `build/` 忽略规则
- README: unchanged：仅调整卡片末尾标点，无使用方式或命令变化
- AGENTS.md: unchanged：沿用现有界面开发与验证流程，无持久开发规则变化
