# 关于页 GitHub 图标修复

- 根因：`CommandGitHub` PNG 带不透明白底，原生按钮将其作为模板渲染时，整张图片被染成实心方块。
- 修复：关于页按钮使用独立的 `GitHubMark` 透明矢量模板，来源为 GitHub Primer Octicons；MIT 许可及来源说明随应用打包。原网站指令资源保留。

实际执行结果：

- `xcodegen generate` 与 README 中 Debug `xcodebuild` 命令通过。
- `codesign --verify --deep --strict` 对本次 Debug 构建产物通过。
- 按 README 构建 MCPBridge、安装并构建 AgentRuntime 后，`Packages/KulaCore` 的 `swift test` 共 262 项测试通过。此前缺少 `AgentRuntime/dist/src/plugin-runner.js` 的两次运行失败，不计为通过。
- 设置回归首次编译因并行构建修改 `Scheduler.o` 失败；复制构建产物至 `build/GitHubIconDerivedData`，使用 `ASKY_DERIVED_DATA` 重试后编译成功，但完整运行在 `SettingsRegression.swift:662` 的 MCP 复选框布局断言处失败，因此不声称完整设置回归通过。
- 使用该次编译得到的 `SettingsRegression.app --preview` 实际打开关于页，通过 UI 切换测试窗口主题：浅色图标为黑色、深色为白色，GitHub 轮廓及内部镂空均清晰，未出现方块。测试使用临时数据，不修改正式应用偏好。
- `git diff --check` 通过。构建与依赖产物沿用既有忽略规则。

README 与 AGENTS.md 无需更新：修复未改变使用方法、开发命令或架构约束。
