# 快捷入口 command_line 图标

- 将快捷方式（`ql`）从 Link 图标映射中拆出，使用已有 MingCute `command` 线性矢量资产（`command_line`，⌘）。保留蓝色底板。
- 快捷指令分类（`sc`）同步使用该图形，保留紫色底板。搜索指令设置、分类搜索结果与输入模式通过 `LauncherFunctionIcon` 共享映射。
- Link 继续使用 `link` 图形；复用已有矢量资源、16 pt 白色图形及 20 pt / 5 pt 圆角底板。

## 实际执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过（`BUILD SUCCEEDED`）。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：267 项测试通过。
- 已启动新构建 Debug 应用；原生 UI 自动化在操作窗口时返回 `noWindowsAvailable`，未完成实际窗口截图验收，不将视觉验收记为通过。

README 与 AGENTS.md 经检查无需更新：仅调整现有共享图标映射，未改变操作方式、开发命令或架构边界。
