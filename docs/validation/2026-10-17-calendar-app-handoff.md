# 创建日程交给 macOS 日历

- 提醒卡片的“创建日程”通过 ToolService 生成单事件 ICS，并指定 `com.apple.iCal` 打开；标题、起止时间、地点与摘要随文件交接。
- 移除 Asky 内日程配置表单、模型及其独立编辑器回归入口。卡片入口不再提交 `calendar_create_event`，不报告“日程已创建”；交接后保留卡片供再次打开或稍后处理。
- 临时目录与文件权限分别为 0700、0600；失败时移除文件，成功时保留供日历读取。相同来源使用稳定 UID。
- `xcodegen generate`：通过。
- README 的 Debug `xcodebuild` 命令：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，包括新增的 3 个 CalendarHandoffTests，覆盖 UTC 时间、文本注入转义、UTF-8 折行、稳定 UID 和无效输入。
- 用临时 Swift 程序调用新构建的实际 ToolService API：成功打开 macOS 日历的“添加日程”窗口，要求选取目标日历。未在验证中确认添加，不将应用打开视为事件保存。
- 提醒卡片到日历的完整真实短信链路未触发；验证覆盖实际交接 API、日历窗口和调用点代码审查。
- README 中英文及开发文档已同步。AGENTS.md 规则与模块边界保持有效，无需调整。
- 测试产物使用已有 build/ 忽略规则；临时预览程序位于 /tmp，未进入版本库。
