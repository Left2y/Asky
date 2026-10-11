# 计算卡片上下布局验证

日期：2026-10-11

- 将横向公式、等号、结果改成上下布局：公式左对齐，结果右对齐，行间距 12 pt；去掉中间独立等号。
- 保留字号、颜色、卡片外观、输入补全与回车复制行为。
- README 中英文同步描述。

已执行：

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `python3 App/Tests/run-launcher-calculation-regression.py`：通过，创建真实 LauncherPanel，覆盖浅色、深色、长公式、大数、补全与原有汇率流程。
- 检查本轮原生面板捕获 `build/calculator-long-NSAppearanceNameAqua.png` 与 `build/calculator-NSAppearanceNameDarkAqua.png`：公式左上、结果右下，长公式截断且结果完整。
- Debug 主程序重新启动。Orca 未列出该后台应用，主程序键盘输入尚未通过 computer-use 验收；视觉证据来自真实原生回归窗口的视图捕获，不证明窗口阴影或玻璃合成。

构建日志与截图复用现有 `build/` 忽略规则。
AGENTS.md: unchanged，未改变命令、模块边界或子项目。
