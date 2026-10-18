# 剪贴板删除操作语义色

列表更多菜单的“删除记录”和“清空全部”文字显式使用 `ThemeColor.kTextNegative`，图标沿用原有颜色。卡片菜单的两个破坏性按钮标签也使用该 token，并保留 destructive role。操作及确认流程不变。

已执行：

- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- 用当前 App 源码编译临时原生预览，打开列表更多菜单，分别捕获浅色与深色视图位图并目视检查：两项文字均为 negative 红色，复制文字保持原有色。预览与截图存于已忽略的 `build/`，无需新增忽略规则。[浅色](../../build/clipboard-negative-light.png)、[深色](../../build/clipboard-negative-dark.png)。位图用于验证文字颜色，不作为系统玻璃合成验收；卡片系统菜单未单独截图验收。
- 既有 `--layouts --more-motion` 回归未通过：在到达菜单检查前，系统 `screencapture` 返回 `could not create image from window`（ClipboardRegression.swift:428）。未改动该无关截图流程，以上独立原生预览验证颜色。

README: unchanged — 本次仅调整文字语义色，使用方法和功能不变。
AGENTS.md: unchanged — 未改变模块边界、规范或开发命令。
