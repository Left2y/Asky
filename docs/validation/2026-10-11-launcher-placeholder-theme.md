# 启动器占位文字主题修复

## 改动

启动器 `LauncherSearchField` 显式使用 `kTextSubtle` 作为占位文字颜色，避免 AppKit 默认占位灰色与应用主题不一致。输入文字与按钮图标继续使用已有语义主题色。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 `Packages/KulaCore`）：通过。
- `xcodegen generate` 与 README 的 Debug `xcodebuild` 命令：通过。
- README 的独立 `LauncherSearchFieldRegression` 编译及运行：通过。
- 临时原生探针使用实际 `LauncherController` / `LauncherView`，在同一窗口依次切换暗色、亮色、暗色：通过。读取 `placeholderAttributedString` 的颜色，暗色为白色、alpha 0.7；亮色为 RGB 0.054902 / 0.0588235 / 0.0666667、alpha 0.7。输入文字同步切换，alpha 0.9。
- 检查 WindowServer 窗口截图：暗色输入文字、搜索/固定/筛选图标为浅色，亮色为深色。截图期间有真实键盘输入，因此部分截图显示输入内容；占位颜色另由原生属性断言确认。

临时探针位于 `/tmp`，产物位于现有忽略的 `build/`。未打包、安装或发布。

## 文档门禁

- README: unchanged：修正现有主题行为，没有改变使用方式或开发命令。
- AGENTS.md: unchanged：没有改变模块边界、开发流程或持久规则。
