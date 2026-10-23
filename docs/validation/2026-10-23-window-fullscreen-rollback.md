# 撤销窗口全屏操作

- 按用户取消要求移除进入／退出全屏操作、对应快捷键和设置项。
- 撤销跨 Space 的引用缓存、窗口 ID 补查和延迟解析，恢复原有 AXWindows 枚举及身份校验。
- 保留关闭窗口、上一屏／下一屏；全屏状态只用于屏幕切换的可用性判断。
- 原全屏及跨 Space 验证记录已标为历史结果；README 中英文与 PRD 已同步。
- AGENTS.md 无需修改：现有 App、ToolService 边界与构建要求仍适用。

实际执行：
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData-fullscreen build`：BUILD SUCCEEDED。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，13 个测试运行合计 307 项。
- `codesign --verify --deep --strict build/DerivedData-fullscreen/Build/Products/Debug/Asky.app`：通过。
- `git diff --check`：通过。
- 已结束旧仓库 Debug 进程并打开上述新构建，进程 PID 92383。

未进行物理键盘、实际窗口菜单或性能验收；流畅度由用户继续试用确认。并行插件／设置工作未回退。本次取消不创建提交。
