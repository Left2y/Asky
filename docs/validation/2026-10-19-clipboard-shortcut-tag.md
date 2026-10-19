# 剪贴板菜单快捷键描边

“更多”菜单的“复制到剪贴板”快捷键改用 `LauncherActionKeyCap`，与底部操作按钮统一为 20 pt 高、5 pt 圆角、1 pt 主题描边。

已执行：

- `xcodegen generate` 与 README 的 Debug `xcodebuild` 命令：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts`：通过。
- 检查当前源码的原生窗口位图：[浅色](../../build/clipboard-layout-actions-menu-light.png)、[深色](../../build/clipboard-layout-actions-menu-dark.png)，菜单复制快捷键均有圆角描边。位图不作为完整系统玻璃合成的验证。

README: unchanged — 样式修复未改变使用方法或命令。
AGENTS.md: unchanged — 沿用已有组件与验证流程，无持久规则变化。
日志、截图和回归构建均沿用 `build/` 忽略规则，无新增规则。
工作区原有的底部回车符号修改保留，不纳入本次提交。
