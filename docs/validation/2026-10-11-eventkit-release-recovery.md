# Release 日历读取异常与恢复验证

日期：2026-10-11

## 现场证据

- 已安装并运行的版本：0.0.11（build 11），路径为系统 Applications 下的 Asky.app。
- 故障会话两次 `calendar_list_calendars` 均返回 `completed`、`output: []`，模型据此宣称没有可用日历。
- 系统日历 App 实际有日程。重启后的同一已安装 Release 经 AI → AgentRuntime → ToolService → EventKit 只读调用，返回 5 个日历、3 个可写日历，且有可写系统默认日历；未创建或修改日程。
- 因而故障不能解释为用户没有配置系统日历。源码中 Settings 授权使用的 EKEventStore 与工具实例分离，工具在授权变化后没有 reset，符合授权前实例缓存未刷新的机制；未通过撤销真实权限再授权重现，不把这个机制描述为已完成全部现场复现。
- Apple 文档明确说明，授权前访问过的实例需在获得权限后 reset：[requestFullAccessToEvents](https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents(completion:))。

## 修复

- EventKitBridge 记录日历与提醒事项的授权状态；首次使用及后续访问时检查变化，发生授权/撤销/重新授权变化则 reset 工具持有的数据实例。共享实例的状态判断由锁保护。
- 日历/提醒列表为空时，仅做一次只读 reset/刷新尝试；仍为空则返回数据读取异常，明确不能判断账户为空或连接异常，防止返回成功空数组诱导错误结论。
- 日程搜索先确认能读取日历列表，再返回范围内匹配结果；提醒事项同样先确认列表，nil fetch 回调报告读取失败。
- Runtime 将普通读取与写入回读的完成提示区分；提示模型不要将读取失败、空匹配或历史错误推断为账户不存在。

## 实际检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。日志报告共 192 项测试，包含 1 项未启用的 live GitHub/Orca 检查；新增日历与提醒授权变化回归通过。
- `cd AgentRuntime && npm test`：7 项通过，包括读取结果不声称写入回读验证的回归。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Release -derivedDataPath build/CalendarFixDerivedData build`：通过，最终修改后增量构建也通过。Xcode 输出 CoreDevice/Simulator 插件警告，未阻断 macOS 构建。

## 其他模块的验收边界

已安装 Release 经实际 AI/工具链读取：`shortcuts_list` 返回 5 项；`chrome_list_tabs` 返回 5 项；`reminders_list` 返回成功空数组。提醒事项没有核对真实列表，因此只记为调用返回，不能判定数据完整性。

故障前备忘录工具返回未选择授权文件夹的明确权限错误；通讯录搜索返回空匹配。这些证据不能证明备忘录与通讯录完整可用。修改、删除、消息交接和日历/提醒写入未在本次执行，不能宣布所有系统能力通过。

源码回归和构建不等于修复后真实权限变化验收。未重置用户 TCC 权限；未替换安装包或发布新版本。工作区同期有其他 UI 修改，仅将本次日历/Runtime/说明变更纳入提交。
