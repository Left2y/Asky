# 更新卡片说明文字

- 移除关于 Asky 页面软件更新卡片底部的说明文字及对应说明行。
- 保留更新状态、检查更新按钮和安装确认逻辑。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，23 个测试。
- 已启动新构建的 Debug 应用；有多个 Asky 实例运行，原生 UI 自动化未取得新实例的设置窗口，尚未完成目视验证。
- README 与 AGENTS.md 检查：没有使用流程、命令或架构边界变化，无需修改。
- 工作区其他并行改动未纳入此任务提交。
