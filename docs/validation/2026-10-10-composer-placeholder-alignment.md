# AI 输入提示与光标对齐

- 移除 SwiftUI 提示叠层，在原生 NSTextView 内使用 TextKit 绘制「输入你的任务」，与输入文字共用字体、文本容器参数及起点。
- 移除 NSTextContainer 默认的 5 pt 行片段边距，保留外层 20 pt 水平内边距及编辑器 4 pt 顶部内边距。
- 空输入时显示提示（包括聚焦状态），输入或输入法组合文字时隐藏；清空后恢复。此记录更新此前焦点隐藏提示的验收状态。

## 实际验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- 核心包首次使用 Command Line Tools 执行 `swift test` 因缺少 Testing 模块失败；使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 重跑：140 tests / 28 suites 通过。
- `python3 App/Tests/run-agent-reply-regression.py --preview`：编译实际 App 源码，在临时数据库中打开原生 AI 窗口；通过 Orca 截图确认空输入提示与起点光标对齐。
- 原生可访问性输入「输入位置验证」并读回：提示隐藏，文字与提示的第一字位置一致；清空并读回：提示恢复。未发送消息或调用模型。
- 截图包含深色外观的实际 720 × 640 pt 窗口；未专门验证浅色外观及输入法组合过程。

README: unchanged — 小型位置修复，现有使用方式、开发命令及架构不变。
AGENTS.md: unchanged — 未引入新的持久规则或模块边界。
