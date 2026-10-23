# 全屏窗口隐藏跨屏菜单

> 历史记录：全屏／窗口化操作及跨 Space 补查已按用户要求撤销；下文仅保留撤销前的验证结果，不代表当前功能。屏幕切换功能保留。

日期：2026-10-23。

- 选中窗口处于系统全屏时，`⌘K` 隐藏“切换到上一块屏幕 / 下一块屏幕”；保留“退出全屏”和底部红色“关闭窗口”。退出全屏后，多屏环境恢复两项；单屏隐藏规则保持。
- KulaCore 全套 `swift test` 通过；`xcodegen generate` 与 Debug `xcodebuild`（`build/DerivedData-display-move`）通过；应用签名 `codesign --verify --deep --strict` 通过。
- `ASKY_DERIVED_DATA="$PWD/build/DerivedData-display-move" DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --window-search` 首次在 `Command K must open window menu` 断言失败；未改源码，直接重跑同一回归可执行文件后通过，包含菜单状态、单屏隐藏、键盘选择、Esc 和浅色/深色截图。首次失败原因未确定。
- 已查看实际原生回归窗口的深色截图：全屏状态只显示“退出全屏”和“关闭窗口”，屏幕切换项已隐藏。
- 本次菜单回归注入全屏状态；没有重复真实窗口跨屏、系统全屏切换或物理键盘验收。此前系统操作的验证记录见 `2026-10-23-window-display-actions.md`。
- README 中英文与 PRD 已同步；既有构建、进程与系统操作边界未改变，AGENTS.md 无需更新。产物继续由既有 `build/` 规则忽略。
