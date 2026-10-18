# 剪贴板移除记录固定

日期：2026-10-18。

移除列表“更多”菜单中的 Pin / Unpin、卡片菜单的固定记录操作、记录固定标记及 `⌥⌘P` 处理。无外部输入目标时列表菜单仅显示删除；有输入目标时保留复制与删除。顶部窗口固定按钮保留。兼容旧数据库中的固定字段、记录及保留策略，不清除既有用户数据。

实际执行：

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts`：通过，覆盖旧 Pin 快捷键无效、单项菜单键盘边界、删除、复制与布局切换。
- `python3 App/Tests/check-localization.py`：通过，142 个 Swift 源文件。
- `git diff --check`：通过。

已查看本次新编译原生窗口的[浅色菜单](../../build/clipboard-layout-actions-menu-light.png)和[深色菜单](../../build/clipboard-layout-actions-menu-dark.png)，菜单仅显示删除记录，无 Pin。未另行验证真实外部输入目标的粘贴链路。

README 中英文与 PRD 已同步；AGENTS.md 的工作流与架构规则未变化。构建与截图沿用 `build/` 忽略规则。

任务开始时 ClipboardWindow.swift、ClipboardRegression.swift、README.md 等已有未提交修改，本次直接调整其中操作菜单及对应回归代码，无法将完整任务与既有工作可靠隔离，因此未自动提交；保留全部既有修改。
