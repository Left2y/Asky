# 行内代码圆角修复

日期：2026-10-11。

此前使用 NSLayoutManager 的 enclosing selection rect 作为背景范围；该范围包含行距，绘制向文本视图边缘延伸时，顶部圆角被裁切，视觉接近直角。

现在逐行按代码字体的 baseline、ascender 与 descender 计算独立背景范围，保留上下 2 pt 空间与原有左右内距，使用 8 pt 圆角。换行片段分别绘制，不改变正文或表格样式。

已执行 KulaCore 的 swift test（全部通过）、xcodegen generate 和 README 声明的 Debug xcodebuild（成功）。重新编译实际 App 源码并启动浅色／深色原生预览，经 computer-use 截图检查四角完整且形状明显。预览与日志沿用已有 build/ 忽略规则及系统临时目录。

README: unchanged，现有功能与开发命令描述仍准确。AGENTS.md: unchanged，未改变模块边界、命令或持久规则。
