# 2026-10-12 后台 AI 建议接入短信

## 变更

- `ToolService/MessagesHistory.swift`：`MessagesHistoryReader` 只读读取 `~/Library/Messages/chat.db`，手工解析 `attributedBody`，丢弃验证码短信、遮盖长数字与未知号码。
- `SystemPermission.fullDiskAccess`：系统权限页新增“完全磁盘访问（读取信息）”，走拖拽授权卡片，状态以能否只读打开数据库判断。
- `Scheduler/MessageTriage.swift`：第一步分批提炼。仅处理水位线之后的新消息，每批约 2,500 字、单轮最多 6 批，附同会话前 3 条上下文，产出至多 30 条 `MessageNote` 并可标记旧事项已解决；状态存于本地设置 `reminders.messages.triage`。
- `SmartAdvisor`：输入改为 `[MessageNote]`（S 编号），不再接触短信原文；事项可作锚点，记忆不能作为锚点。
- `ContactsBridge.nameIndex()`：号码/邮箱映射为联系人姓名。
- 设置 › 数据来源 › 情境提醒：新增“让后台 AI 读取最近 30 天的短信与 iMessage”（默认关闭，依赖后台 AI 判断）。

## 已运行检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：全部通过；新增 MessagesHistoryTests 3 项、MessageTriageTests 4 项（分批、每条只发一次、失败续读与非法编号、过期丢弃）、SmartAdvisorTests 1 项，SystemPermissionTests 覆盖新权限。
- `xcodegen generate` 后 `xcodebuild -scheme Asky -configuration Debug build`：BUILD SUCCEEDED。
- 手工解析器与 `NSUnarchiver` 在本机最近 300 条真实 `attributedBody` 上逐条对比：300 条一致。
- 在本机真实数据库上运行读取器（仅输出统计）：最近 3 天原始 6 条，2 条验证码短信被丢弃，保留 4 条；无残留 8 位以上数字。
- 读取窗口改为 30 天：本机 30 天过滤后 114 条，共约 10,700 字，平均 93 字/条。单次一万字偏大，因此改为两步：按 2,500 字分批约 5 批，首次开启一轮读完，之后每轮只发送新增消息；提醒判断请求只携带至多 30 条短事项。

## 未验证

- 未在打包后的 Asky.app 中实际授予完全磁盘访问并走完拖拽授权流程（本次读取在已有权限的终端中进行）。
- 未用真实模型验证分批提炼的事项质量、已解决判断以及通知弹出。

## 提交前复验

- 2026-10-12：重新运行 KulaCore 的 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，223 项测试通过。
- 重新运行 `xcodegen generate` 与 README 中的 App Debug 构建命令，结果为 `BUILD SUCCEEDED`。
- 本次仅复验测试与构建，未新增真实模型、通知或 App 内权限流程验收。
