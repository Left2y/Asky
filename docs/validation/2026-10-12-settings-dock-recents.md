# 设置关闭后的 Dock 图标留存诊断

环境：macOS 27.0.1 (26A434)，安装版 Asky 0.0.13 与本地 Debug 构建。

## 实际结果

- 打开设置时 Dock 出现 Asky 图标；关闭设置后安装版仍可留下一个图标。
- 通过 `NSWorkspace.shared.runningApplications` 读取，关闭后的 Asky 激活策略为 `accessory`（原始值 1）。
- Dock 中残留图标的辅助功能属性 `AXIsApplicationRunning` 为 `false`。
- 只读检查 `com.apple.dock`：Asky 不在 `persistent-apps`，但在 `recent-apps`，路径指向 `/Applications/Asky.app/`。因此残留的是系统最近使用入口，而不是运行中图标或用户固定入口。
- 将关闭回调中的模式切换延后一个主线程循环，重新构建并运行后，安装版最近使用入口依然存在。该实验未解决报告的问题，源码改动已撤回。

## 检查

- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过（实验版本）。
- 默认工具链 `swift test`：失败，缺少 `Testing` 模块。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，23 个测试。
- 原生设置窗口通过菜单栏打开并点击关闭；Dock 属性与系统偏好使用只读检查。结束时退出测试开发进程，重新打开安装版，未修改 Dock 偏好或覆盖安装版。

## 结论

此次没有提交应用行为修复。当前关闭逻辑已恢复后台模式，但不能保证系统最近使用区域同时移除入口。Apple 的[桌面与程序坞设置说明](https://support.apple.com/en-ie/guide/mac-help/mchlp1119/27/mac/27)确认“显示建议和最近使用的 App”会展示尚未固定到 Dock 的最近应用。关闭该系统选项会影响所有应用，需要用户选择，不能作为 Asky 自动修改的全局设置。
