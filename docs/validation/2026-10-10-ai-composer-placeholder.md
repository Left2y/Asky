# AI 输入框占位文字

- 空输入时显示「输入你的任务」，聚焦不再隐藏；非空输入时隐藏。
- 仅修改 Composer 的占位文字条件，保留焦点、编辑与提交行为。

## 验证

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：140 项测试、28 个套件通过。默认工具链首次运行缺少 Testing 模块，切换 Xcode 工具链后通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- 未进行运行中界面验证，未打包 Release 或安装。
- README 与 AGENTS.md 无需因这一处占位文字修正而调整。
