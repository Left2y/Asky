# 搜索与剪贴板操作菜单去除左侧图标

移除 `LauncherActionsMenu` 和 `ClipboardActionsMenu` 每行左侧的图标视图，不保留空图标槽。文字、右侧快捷键、选中背景、键盘操作与删除项 negative 文字色保持原有实现。

已执行：

- `xcodegen generate`：通过。
- README 的 Debug `xcodebuild` 命令：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- 当前源码编译的临时原生预览：通过。剪贴板更多菜单浅色、深色位图已检查，文字直接使用行内边距，左侧没有图标或占位，删除文字仍为 negative 红色。[浅色](../../build/clipboard-no-icons-light.png)、[深色](../../build/clipboard-no-icons-dark.png)。位图不包含系统玻璃合成。
- 搜索菜单通过源码检查及构建验证；临时搜索预览仅出现输入框，未将其记为菜单视觉验收。

README: unchanged — 仅移除装饰图标，使用方法和功能未变。
AGENTS.md: unchanged — 沿用现有架构、样式规范和验证命令。
临时预览源码、二进制和截图沿用已忽略的 `build/`，没有新增忽略规则。
