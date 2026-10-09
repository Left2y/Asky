# 日历目标选择修复验证

日期：2026-10-09。

## 问题与修复

截图显示 calendar_create_event 返回“找不到目标日历”。旧实现未指定目标时仅查询 defaultCalendarForNewEvents；这个可选值为空就失败，且工具目录没有日历列表能力。尚未直接确认本机 EventKit 默认值与账户状态。

- 新增 calendar_list_calendars，经原生 ToolService 的日历授权检查返回 ID、名称、账户、可写与默认状态，供 Agent 与 MCP 使用。
- 创建支持准确名称和 ID。同名目标要求 ID；明确指定的不存在或只读目标不会换成其他日历。
- 默认不可用时，只有一个可写日历才自动选择；多个候选返回实际选项，无可写日历提供启用账户或创建日历的恢复说明。
- Agent 提示先查询真实日历，不猜测名称。预览与执行共用选择逻辑，现有冲突检查和写入回读保留。

## 实际执行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：113 项测试、23 个套件通过。新增 7 项目标选择与工具注册测试，无真实日历读写。
- `npm test`（AgentRuntime）：4 项测试通过，同时编译 dist。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。

- 已退出旧 App 并重新打开 Debug 构建；首次打开与退出发生竞态，返回 -600，重试 open 成功并确认新进程 PID 46719。

## 验证边界

自动化验证不证明本机账户或默认日历已正常配置，也未创建真实日程。需在新构建中重试原请求，确认实际日历查询、目标选择与写入回读。原有 LauncherView 修改随工作区构建，但不纳入本次提交。
