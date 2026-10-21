# 设置标题左对齐验证

设置工具栏标题增加文字缩进，与正文分组标题和卡片左边缘对齐。原生 NSTextField 的 intrinsicContentSize 同时包含缩进，避免工具栏按未缩进文字宽度重新布局而裁掉末字。

已执行：

- `xcodegen generate` 与 README 的 Debug `xcodebuild` 命令：通过
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：298 项通过
- 最终 SettingsRegression 二进制 `--navigation-settings`：通用、搜索、剪贴板浅深色快照和导航配置持久化通过
- 新编译的真实设置窗口：中文“指令”和“别名与快捷指令”完整显示，与下方分组标题左边缘对齐，标题无额外胶囊背景

截图：[指令](../../build/settings-heading-commands.png)、[长标题](../../build/settings-heading-aliases.png)

限制：完整设置回归首次运行在 MCP 复选框标签布局断言中止，不能记为全部通过。并行任务改写源码和共用构建产物时，截图工具编译多次中止；最终使用源码和 Debug 依赖的临时副本编译实际窗口后完成上述视觉检查，未改动回归脚本。

README 与 AGENTS.md 不变：仅修正现有布局，不改变使用方式、命令或架构约束。截图和回归产物沿用既有 build/ 忽略规则。
