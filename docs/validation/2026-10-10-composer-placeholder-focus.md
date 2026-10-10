# AI 输入框焦点提示修复

- 空输入且未获得焦点时显示「输入你的任务」；原生 NSTextView 成功获得焦点后隐藏提示，成功移交焦点后恢复空输入提示。
- 焦点状态通过原生 becomeFirstResponder / resignFirstResponder 回传 SwiftUI，不改动发送、换行或附件处理。

## 实际执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：133 tests / 27 suites 通过。
- 启动 Debug App，通过 cua_repl 读取窗口和截图：新对话的「消息输入」为空且是 focused UI element，提示文字未显示。
- 用户随后在窗口输入了草稿，停止自动交互以保留输入；清空及焦点移交场景未完成手动验证。

README：本次是小型视觉修复，现有使用方式及开发命令不变，无需修改。
AGENTS.md：现有命令和模块边界不变，无需修改。
