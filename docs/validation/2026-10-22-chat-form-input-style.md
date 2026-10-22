# 原生表单输入框外观修复

日期：2026-10-22。问题：聊天表单文本框使用 SwiftUI 默认 `.roundedBorder`，在暗色玻璃表面显示突兀的黑色填充和系统焦点外框。

改动仅限表单文本框：保留原生 TextField 编辑，改为 `.plain`，复用设置页已有的 `settingsInputSurface` 半透明背景、6pt 圆角和聚焦描边。输入仍支持单行编辑、中文输入和流式回复完成时保留焦点；表单周围的选择器、按钮与提交行为没有修改。

## 实际执行结果

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：成功。
- `codesign --verify --deep --strict build/DerivedData/Build/Products/Debug/Asky.app`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：298 项通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-agent-reply-regression.py --forms-preview`：通过。真实原生输入、流式完成后的控件实例和焦点保留、选择器绑定、提交及重开历史均通过；增加深浅色聚焦/非聚焦和暗色禁用截图。
- `python3 App/Tests/check-localization.py`：154 个 Swift 文件检查通过。
- 任务文件的 `git diff --check`：通过。工作区 README 的并行改版含 Markdown 行末双空格，不属于本次修改，保持原样且不纳入提交。

原生回归第一次与 Xcode 构建重叠，编译器发现 MarkdownUI.o 被构建进程改写而中止；等待构建完成后独立重跑成功，不以失败尝试作为通过依据。

## 已查看的实际窗口截图

- [暗色聚焦](../../build/form-field-dark-focused.png)：半透明浅填充和 2pt 聚焦描边，去除系统默认黑底及外扩焦点框。
- [暗色普通状态](../../build/form-field-dark-idle.png)：低对比边框。
- [浅色聚焦](../../build/form-field-light-focused.png)：文本框与周围表面保持一致。
- [暗色禁用](../../build/form-field-dark-disabled.png)：输入不可编辑，保留表面样式。

截图及日志复用现有 `build/` 忽略规则。仅判断本次文本框样式，不将截图内其他既有组件作为本次视觉验收范围。未更改 Runtime，不需要运行其测试；没有调用真实模型。

AGENTS.md 无新增持久规则，保持不变。README 的并行编辑由原作者保留；本次修复沿用已说明的原生表单能力，无独立 README 改动。
