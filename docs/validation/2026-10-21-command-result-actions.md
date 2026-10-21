# 搜索指令结果的更多操作

## 行为

- 内置网页指令（如 `go`）的搜索结果提供“编辑快捷指令”和“停用”。
- 编辑打开“设置 › 指令”，清除设置页搜索过滤、滚动到对应输入框并取得原生编辑焦点；已打开的设置窗口可重复定位。
- 停用使用 `ThemeColor.kTextNegative`，写入现有 `disabledBuiltInCommands`，与设置取消勾选一致，并立即重新解析输入、刷新结果。
- 结果关联内置指令的稳定 ID；自定义触发词不会改变启停目标。

## 实际检查

2026-10-21：

- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过；独立 `-derivedDataPath build/CommandActionsDerivedData` 构建亦通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `python3 App/Tests/check-localization.py`：通过。
- 原生 `--command-actions` 回归：Aqua、Dark Aqua 均通过。覆盖 `go` / 自定义 `google`、菜单 negative 语义、打开设置及原生编辑器焦点、已有窗口重复聚焦、带查询参数的指令停用、结果刷新和持久化回读。
- 人工查看实际窗口截图：两种主题菜单的文字与 negative 色正常；设置页面的目标输入框进入编辑状态，自定义 `google` 文本正确选中。
- `git diff --check`：通过。

回归入口已同步至 README。由于其他任务同时修改 LauncherModel 和 KulaCore，原生回归使用 `build/CommandActionsSnapshot` 中的任务源码快照（基线 `c3f990a` 加本次补丁），链接独立构建产物。快照内回归脚本额外启用 Swift whole-module compilation；最终输出 `LauncherWindow native regression checks passed`。该结果不表示并行计算历史功能已经验收。

首次共用构建目录编译遇到 Resources.o 被并行构建修改；后续使用独立产物。测试夹具修正了 AppModel 重置外观、SwiftUI 原生编辑器不暴露包装视图 identifier，以及窗口初始化时输入同步的时序；最终断言读取实际 firstResponder 的文本。

截图位于 `build/CommandActionsSnapshot/build/command-actions-*.png` 和 `command-settings-*.png`。构建产物、快照与截图沿用现有 `build/` 忽略规则，没有新增忽略项。

README: updated — 同步双语使用说明与回归入口。

AGENTS.md: unchanged — 沿用现有 UI、系统操作和验证边界，无新增持久项目规则。
