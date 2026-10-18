# 快捷方式图标替换

- “搜索快捷方式”从 `command` 改为 MingCute `cursor_3_line`（上游 regular/development/cursor_3.svg），沿用锁定版本 `ca98bb55513a22ff0dab713aaf7870b512944653`。
- 通过 `LauncherFunctionIcon.Kind.quickLinks` 共享到指令设置、搜索结果与输入模式；保留原有蓝色底板、白色模板图形和尺寸。快捷指令仍使用 `command`。
- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild`：通过。
- `codesign --verify --deep --strict build/DerivedData/Build/Products/Debug/Asky.app`：通过。
- KulaCore `swift test`：已运行，未全部通过；`PluginTests.nativeWorkerRoundTripAndPolicy` 有 4 个断言失败，插件返回 `pendingVerification` 且 output/readback 为空，日志含 `sandbox_extension_consume failed: 1 (Operation not permitted)`。本次未改动插件实现。
- README 与 AGENTS.md：图标替换未改变使用方式、开发命令或架构规则，无需修改。
- 实际窗口：运行 `python3 App/Tests/run-settings-regression.py --preview --commands`，通过 Orca 读取 Commands 设置窗口并检查截图；快捷方式显示蓝底白色鼠标点击图形，快捷指令显示紫底白色 ⌘，资源正常渲染。该截图为深色外观，未单独验证浅色外观。
