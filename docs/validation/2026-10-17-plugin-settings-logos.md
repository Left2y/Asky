# 插件设置 Logo 恢复验证

- 原因：`4f680d9` 统一插件工具调用图标时，同时移除了 PluginSettings 的图标缓存与读取，将官方和已安装列表替换为 tool 图标。
- 修复：恢复设置页原有图标加载逻辑。官方插件读取 ToolService 提供的应用图标；已安装插件优先读取声明的图标，其次使用对应应用图标，无图标时保留 Plugin 占位。AI 工具调用显示不变。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 首次 `cd Packages/KulaCore && swift test`：失败，Command Line Tools 无法导入 Testing。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，13 个测试运行，共 258 个测试。
- 实际界面：使用新构建 `build/DerivedData/Build/Products/Debug/Asky.app`（PID 14120），打开设置 → 插件；确认官方 Orca、飞书与已安装飞书 / Lark、Orca 共四处均显示原始彩色应用 Logo，36pt 图标槽与列表布局保持一致。
- README：中英文明确 tool 图标仅指插件工具调用，设置页保留 Logo。
- AGENTS.md：unchanged；未改变命令、模块边界或独立子项目。
