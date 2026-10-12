# 设置控件样式与 MCP 选项布局

统一关于页、权限页、模型页及记忆页的表单动作到 `SettingsButton`；别名、终端、模型供应商与插件配置的下拉菜单使用 `SettingsChoice`。模型保存与检查保留原有加载/完成反馈和禁用条件，菜单保留终端与快捷指令图标。

外部 MCP 的工具复选框改用原生带文字控件，以自适应网格排列，避免只显示勾选框及纵向扩张。选择仍更新原实例的来源列表。

## 已运行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/SettingsUnifiedDerivedData build`：通过。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `ASKY_DERIVED_DATA=build/SettingsUnifiedDerivedData python3 App/Tests/run-settings-regression.py`：通过。使用真实设置窗口与临时数据目录，覆盖亮暗外观；新增 MCP 实例 fixture，并验证七个复选框均有标题且高度不超过 32pt。
- 人工查看原生回归图片：`build/settings-light-about.png`、`build/settings-light-permissions.png`、`build/settings-light-aliases.png`、`build/settings-light-mcp.png`、`build/settings-dark-mcp.png`。按钮/菜单背景一致，MCP 文字可见，选项排列紧凑。

## 边界

视觉证据来自使用当前源码的原生回归窗口，不是已安装 Release。真实应用窗口的自动化因同名进程和用户同时操作发生冲突，未据此宣称已安装版本完成验收。未触发系统权限申请、修改用户 MCP 权限、保存模型凭据或安装更新。

README 与 AGENTS.md 无需更新：本次修正控件外观和布局，现有开发命令、模块边界与使用流程保持一致。构建与截图产物复用现有 `build/` 忽略规则。
