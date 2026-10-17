# Asky 内日程配置弹窗

- 使用独立 380 × 480 原生玻璃窗口，窗口与圆角表面等大，经 WindowSurface 承载系统阴影。标题与时间为带强调色的首组，地点、目标日历、备注为独立圆角分组，无旧 NSAlert 大图标和说明段落。
- 日期行展开 280 点宽的月历、开始/结束切换与数字小时/分钟菜单。月历使用 SwiftUI 日期网格，每格高 34 点，支持月份导航、今日提示和选中状态；移除 AppKit 旧式小月历、模拟时钟与步进按钮。
- 目标日历经 ToolService 的 calendar_list_calendars 读取，只允许可写日历，优先默认日历。标题、起止时间、地点、所选日历 ID 和备注经 MessageCalendarCreation 交给 ToolService 创建并回读，不再启动 Calendar 或生成 ICS。
- 成功后关闭窗口并处理提醒；冲突时保留输入并显示行内错误。写入中禁用重复点击和关闭；未知结果禁止再次创建，同来源后续操作复用持久化请求。
- 扩展草稿的 calendar、notes 为可选字段，旧缓存仍可解码。
- xcodegen generate 与 README Debug xcodebuild：通过。
- KulaCore swift test：通过。新增回归覆盖日历/备注转交及旧草稿解码；原有同来源并发去重、待核实恢复和失败重试测试通过。
- python3 App/Tests/run-calendar-editor-regression.py：模型校验通过。--preview --preview-error 打开实际新窗口，使用模拟结果，不读写真实日历。
- 实际窗口确认标题、地点、日历和备注字段，日期弹层包含新月历与数字时间菜单；选择日期保留原小时/分钟的回归通过。不将真实 EventKit 保存记为本次实机验证通过。完整真实短信提醒触发未运行。
- README 与开发说明中英文已同步；PRD 改为在 Asky 内完成配置和保存。AGENTS.md 无持久规则变化。
- 构建与预览包沿用 build/ 忽略规则，保留并行任务的其他修改。
