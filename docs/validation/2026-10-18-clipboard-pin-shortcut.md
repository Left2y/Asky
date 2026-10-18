# 剪贴板 Pin / Unpin 快捷键验证

日期：2026-10-18。

- `⌥⌘P` 对当前所选记录切换固定状态，复用既有菜单动作并在排序后保留选中记录；菜单打开时执行会关闭菜单。
- 精确匹配 Option + Command + P，额外 Shift 不触发；忽略按键重复事件，避免长按反复切换。Pin / Unpin 行右侧显示快捷键。

实际执行：

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts`：通过。覆盖直接快捷键固定、菜单打开时快捷键取消固定、额外修饰键不触发、排序后保留选择，以及原有布局、筛选和复制流程。
- 已查看实际窗口截图 `build/clipboard-layout-actions-menu.png`：Pin 行右侧显示 `⌥⌘P`，未截断或挤压文字。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：未通过。`PluginTests.nativeWorkerRoundTripAndPolicy` 的 4 个断言失败，首个断言为缺少 `AgentRuntime/dist/src/plugin-runner.js`；其余测试套件通过。尝试 `cd AgentRuntime && npm run build` 准备依赖产物失败，报告缺少 Node 类型/模块等依赖。未修改运行时源码或依赖配置。
- `git diff --check`：通过。

README 中英文已同步快捷键；本次未改变架构、命令或持久开发规则，AGENTS.md 保持不变。构建与截图沿用现有忽略规则，不纳入提交。
