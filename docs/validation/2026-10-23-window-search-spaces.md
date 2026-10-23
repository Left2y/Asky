# 全屏后其他 Space 窗口漏检

日期：2026-10-23。

## 复现与原因

两个同名 AppKit 窗口中，一个进入系统全屏后，应用的 `AXWindows` 从两个窗口变成一个；另一个窗口仍能读取 `AXRole`、`AXTitle`、`AXParent` 和全屏状态。关闭窗口后，其原始引用返回 `invalidUIElement`。

旧实现仅从当次 `AXWindows` 枚举搜索结果，执行前也要求目标仍在该数组中，因此既会漏列其他 Space 的窗口，也会拒绝对已知存活窗口的操作。前次全屏测试用 NSWindow 状态核对窗口身份，未覆盖全屏后重新刷新列表及跨 Space 操作。

## 修复

- ToolService 的串行目录保留当前进程内最多 512 个已发现窗口的精确 AX 引用，刷新时合并仍有效的窗口。窗口关闭、应用退出、PID 启动时间改变后清理；不落盘、不添加定时轮询。
- 对不在当次 `AXWindows` 中的原始目标，校验其 PID、AXWindow 角色及 AXParent 应用身份，不再把缺席直接等同于关闭；不按标题或应用名寻找替代目标。
- 每次搜索面板仍使用独立快照，目录只补充此前已发现并且仍有效的窗口。尚未被系统暴露过的窗口、应用不提供的窗口不作覆盖保证。

## 实际执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData-fullscreen build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `ASKY_DERIVED_DATA=/Users/niallyoung/orca/Asky/build/DerivedData-fullscreen python3 App/Tests/run-launcher-window-regression.py --window-search-spaces`：通过。
- 真实原生双窗口回归：初始两窗口身份不同；一个全屏后连续刷新三次均仍返回两个窗口，状态分别为全屏／窗口化；能切换至其他 Space 中的精确窗口，再回到全屏窗口；从全屏 Space 关闭另一窗口后刷新只剩一个，旧引用的切换及关闭均被拒绝；关闭全部窗口、退出应用后目录无残留。
- `codesign --verify --deep --strict`：通过。重启并确认运行的是 `build/DerivedData-fullscreen/Build/Products/Debug/Asky.app`。

当前设备的真实原生 Space 切换已验证；未逐一验证第三方应用及物理多显示器上所有分屏组合。README 中英文已同步行为及回归命令。AGENTS.md 的现有 ToolService 边界、验证归属和命令入口仍适用，无需修改。
