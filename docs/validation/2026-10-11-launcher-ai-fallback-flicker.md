# 搜索时 AI 兜底闪烁

普通搜索在 100 ms 输入防抖期间就发布了 AI 单条兜底，随后本地批次又展开结果列表。现在只有搜索源全部完成且没有本地匹配时才显示 AI 单条兜底；有匹配的结果仍分批展示并保留 AI 动作。已有结果中仍匹配新输入的具体目标继续保留。明确的对话请求和关键词指令保持原有路由。

## 已执行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/run-launcher-window-regression.py --ai-routing`：Aqua / Dark Aqua 通过。覆盖防抖期间、快源空批次与慢源匹配、连续输入保留匹配、无匹配时最终兜底、等待时回车不提交 AI、取消旧查询及显式指令。
- 新构建的 Asky 已重新启动。通过 Orca 在真实搜索输入框设置 `Safari` 并读回：初次状态只有输入框，随后包含 APP 应用、文件文档、默认搜索及 AI 分类。

## 验证边界

首次回归的固定 450 ms 等待在运行负载下未等到搜索结束，改为最多 3 秒等待完成状态后通过。原生回归通过模型状态采样验证中间阶段；实际窗口的屏幕捕获返回黑色图像，因此此次只确认了原生窗口与辅助功能树，未完成肉眼逐帧视觉验收。

README 与 AGENTS.md 无需变更：这是既有搜索行为的时序修复，没有改变使用步骤、开发命令或模块边界。构建与回归产物由现有 `.gitignore` 覆盖。
