# 审批菜单图标对齐验证

- 将 ApprovalModeRow 拆为居中的标题行（图标、标题、选中勾）与独立说明行，说明文字缩进 30 pt 与标题左侧对齐。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，258 tests。
- 使用新编译的 `python3 App/Tests/run-agent-reply-regression.py --preview` 独立临时数据窗口（PID 72238）打开审批菜单，检查自动审批与完全访问权限两种选中状态：图标与勾选标记均和标题垂直居中，选项切换后按钮值正确更新。
- 构建期间仅有既有 Swift 并发警告；未将警告记为失败。
- 源码修复在本任务验证期间被并行提交 `4f680d9` 收录；本任务不重写该提交，仅单独提交验证记录。
- README: unchanged，微小视觉对齐修复不影响使用方式与开发命令。
- AGENTS.md: unchanged，未新增持久工作流或架构约定。
