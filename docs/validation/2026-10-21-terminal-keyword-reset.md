# 终端触发指令恢复默认

- 终端设置的触发指令输入框右侧增加与指令设置相同的 `SettingsButton`「恢复默认」。
- 点击清除 `terminalKeyword` 自定义值，现有绑定和路由回退到默认 `>`；终端选择与工作目录不变。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 原生视觉与点击验证未完成：Computer Use 两次获取 Asky 应用均返回 `timeoutReached`，包括直接指定新构建应用路径。
- README 与 AGENTS.md 检查：本次仅补齐现有设置操作，无开发命令、模块边界或使用流程变更，保持不变。
- 保留任务开始前 `SettingsWindow.swift` 的标题缩进修改，不纳入本次提交。
