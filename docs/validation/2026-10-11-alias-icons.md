# 别名设置图标

- 别名列表在目标名称左侧显示 28 pt 图标；应用使用自身图标，快捷指令使用系统 Shortcuts 图标。
- 应用选择/编辑区域与快捷指令选择项同步显示图标，读取复用 ToolService.launcherIcon。
- `xcodegen generate` 与 README 中的 Debug xcodebuild 命令通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）通过：19 tests / 4 suites。
- 使用现有设置回归编译流程与临时测试数据启动真实原生设置窗口，截图确认 Figma、ChatGPT、Shortcuts 列表图标和编辑 Figma 的已选应用图标显示正常。
- 主应用重启后未取得可检查窗口；以上视觉确认来自加载实际 App 源码的设置预览窗口，未验证主应用完整启动流程。
- README 与 AGENTS.md 无需修改：本次仅修复现有设置的图标展示，未改变用法、命令或系统边界。
- 临时预览源码和日志位于 /tmp；编译产物复用已忽略的 build/，不纳入提交。
