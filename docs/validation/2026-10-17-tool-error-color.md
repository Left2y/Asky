# 错误详情按钮点击颜色

日期：2026-10-17。

- 工具错误详情的展开按钮由 `.plain` 改为专用 `ToolErrorDisclosureButtonStyle`，只返回固定 `kTextSubtlest` 颜色的 label，不随 `isPressed` 改变颜色或透明度。
- 保留 Button 语义、辅助功能提示与状态，以及原有详情和箭头动画。
- README: unchanged，本次仅去掉按压时的颜色反馈，使用方法、命令和既有动画说明不变。
- AGENTS.md: unchanged，未引入开发流程或架构规则变化。

已运行：

- `xcodegen generate` 通过。
- README 中完整 Xcode Debug 构建通过。
- KulaCore：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，258 项通过。
- 新编译的原生工具预览（PID 55322）通过展开/收起点击检查。展开中的截图与点击前截图，工具标题文字区域 `(112,208)-(402,240)` 的 RGB 像素差异为零；箭头与详情继续过渡。
- `git diff --check` 通过。

测试产物与日志沿用已有 `build/` 忽略规则，不提交。并行的插件品牌及对话滚动改动保留，提交仅包含本次按钮样式与验证记录。
