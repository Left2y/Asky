# 应用结果补齐文件操作

- 应用结果的“更多”菜单与文件结果一致，提供拷贝、复制路径、复制文件名、展示文件信息；应用包仍不提供“搜索文件夹”。
- 复制文件名及展示文件信息的执行入口允许 `.app` 来源，并继续要求结果具有 Finder 操作；复用 KulaCore 的 ClipboardAccess 和 ToolService，不新增系统访问路径。
- README 中英文同步说明应用结果支持这两项操作。

## 已运行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --action-bar`：完成编译，初次执行存在焦点相关失败（先后出现初始查询被清空、方向键未恢复结果导航）。测试显式激活 NSApp 后，直接运行同一新编译二进制 `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression --action-bar` 重试，浅色和深色均通过。
- 新增断言覆盖应用菜单四项操作、信息项的 `⌘I` 标记、应用包无文件夹搜索、`⌘⇧.` 复制 `Notes.app`、通过菜单回车复制应用文件名并保留窗口及查询。
- 已查看生成的浅深色应用结果窗口截图；未完成应用“更多”菜单的清晰截图验收、物理键盘操作或 Finder 简介窗口/首次自动化授权的实际验证。
- `git diff --check`：通过。

构建和回归均基于包含任务开始前已有窗口搜索、计算历史等未提交改动的当前工作区。这些改动保留且不纳入本次提交。测试截图等产物由现有 `build/` 忽略规则覆盖。

AGENTS.md 无需更新：本次复用现有模块边界、开发命令和指南入口。
