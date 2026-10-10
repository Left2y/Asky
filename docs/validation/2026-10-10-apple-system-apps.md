# 苹果系统应用与日历名称区分

日期：2026-10-10。

## 变更与依据

- 源码确认日程及提醒事项使用 EventKit、通讯录使用 Contacts，短信交接到 Messages；备忘录使用 Notes。未发现大麦适配器或硬编码名称。
- 截图显示的「大麦」可能来自 EventKit 返回的实际日历名称；本次未读取用户真实日历，不能确认其账户或是否确为系统默认。
- 日历查询和日程结果新增 `application: Apple Calendar`；日程结果补充 `calendarID` 和 `account`，确认目标标注「苹果日历」。
- Agent 明确区分应用、日历与账户，不用历史或记忆覆盖实际工具结果。日程、提醒事项、备忘录、通讯录与短信仅接入苹果官方应用及系统接口。

## 已执行检查

- `cd AgentRuntime && npm test`：4 项测试通过，包含 TypeScript 构建。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：116 项测试、23 个测试套件通过。

## 验证范围

未执行真实日程写入、短信发送、现场日历查询或模型回复验证；未重新构建或安装 App。现有会话文字不会被重写，新构建与新请求才能体现变更。

README: updated；中英文同步苹果官方应用范围及日历名称区分。
AGENTS.md: unchanged；模块边界与开发命令未改变，现有规则继续适用。
