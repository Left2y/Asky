# 计算器横向卡片验证

日期：2026-10-11

## 行为

- 计算结果采用现有汇率卡片的中性背景、16 pt 圆角、28 pt 外边距，替代图标列表项。
- 卡片横向显示算式、等号与结果；算式为 20 pt 次要文字，结果为 28 pt 主文字。
- 长算式最多两行，中间截断，保留全文于模型与悬停提示。结果单行，最小缩放比例 0.5，悬停提示保留全文。
- 输入框单行横向滚动；保留浅色结果补全及回车复制原结果。

## 已执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：13 个测试运行、157 项测试通过。
- `python3 App/Tests/run-launcher-calculation-regression.py`：通过，实际创建 LauncherPanel，分别运行浅色及深色，检查短算式、239 字符算式、大数、未完成算式清空卡片、输入补全及原有汇率流程。
- 人工检查原生窗口捕获：短算式无列表项；长算式在卡片内截断且结果完整显示；大数缩小字号，无横向溢出；输入框保持单行。

截图位于忽略的 `build/calculator-{long-,large-}NSAppearanceName{Aqua,DarkAqua}.png` 及 `build/calculator-NSAppearanceName{Aqua,DarkAqua}.png`。

## 限制

已重新启动 Debug 主程序；尝试通过 Orca 操作时面板失焦关闭，`set-value` 返回 `permission_denied`，主程序内输入与卡片未完成自动化验收。上述视觉检查来自实际运行的原生 LauncherPanel 回归进程。

悬停全文通过 SwiftUI 原生 `.help` 实现，未实测悬停提示的出现时机。视图缓存截图不用于证明系统玻璃合成或窗口阴影。

README 中英文使用说明同步。AGENTS.md 未改变：未新增开发命令、模块边界或独立子项目。

用户明确要求提交后，核对暂存区：包含计算卡片、所依赖的计算补全与汇率卡片实现、对应测试和文档。提交这组相关改动；语言设置、剪贴板及其他改动留在工作区。构建与截图继续使用现有 `build/` 忽略规则。
