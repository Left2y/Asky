# 内置网页指令启用复选框

- “设置 › 指令”的八条网页指令在图标左侧显示原生复选框，默认全部启用。取消后指令行仍保留，可再次勾选。
- 启用状态保存于 `app.preferences.v1.disabledBuiltInCommands`；旧设置缺少该字段时默认空集合，保持全部开启。启动器只使用已启用的预设进行空格识别、路由及搜索候选生成。
- `xcodegen generate` 与 README 中的 Debug `xcodebuild` 命令通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 通过。首次未指定 Xcode 的命令因 Command Line Tools 缺少 `Testing` 模块失败，切换到完整 Xcode 后通过。
- `python3 App/Tests/run-settings-regression.py --preview --commands` 编译运行真实设置窗口。新增断言覆盖旧配置默认值、八条指令逐项禁用/启用、禁用后的原始输入及搜索候选、重新创建 AppModel 后的持久化、全关/全开。
- 使用 `orca computer` 读取实际窗口：初始八个复选框均为 1；点击 `go` 后读回 0，其余仍为 1；再次点击后八个均为 1。已检查截图，复选框位于图标左侧，指令与右侧名称保持原布局。截图保留在被既有 `build/` 规则忽略的 `build/command-checkboxes-enabled.png` 与 `build/command-checkboxes-disabled.png`。
- 另运行已编译的 `build/SettingsRegression.app/Contents/MacOS/SettingsRegression`，全部设置页面的浅/深色快照、授权生命周期及卡片拖动回归通过。
- 使用隔离的临时存储验证，未替换已安装的应用。

README: updated — 中英文同步启用方式、关闭后的行为和重启持久化。
AGENTS.md: unchanged — 沿用既有设置持久化、App/核心包边界及构建命令，没有新增长期开发规则。
