# 表单原生时分选择

日期：2026-10-22。补齐截图中“具体时间”仍为文本框的问题：此前组件协议只有 date，模型只能用 text 收集时刻。

## 改动

- 新增 `type: "time"`，支持随回复流逐字段出现。值严格为 24 小时 `HH:mm`，默认当前本地时分。
- 从创建日程弹窗抽出 `CalendarTimePicker`，日程与聊天表单共用小时/分钟选择行及保留日期的时间更新逻辑；选择控件使用共享 SettingsChoice。
- 模型指引要求具体时刻使用 time，上午/下午等时间段仍可用 select。已有消息中的 text 字段保留原始类型，不通过字段名称猜测和修改历史 schema。
- README 中英文、PRD、组件协议示例与开发指南同步更新。

## 实际检查

- `xcodegen generate`、README 的 Debug xcodebuild 命令：成功。
- `codesign --verify --deep --strict build/DerivedData/Build/Products/Debug/Asky.app`：通过。
- `cd AgentRuntime && npm test`：12 项通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：298 项通过。
- 编译并运行 `App/Tests/ChatFormParserRegression.swift`：通过，新增 time 必填、00:00/09:05/14:30/23:59、非法时分及非标准格式校验。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-agent-reply-regression.py --forms-preview --time-preview`：通过。真实原生小时菜单选择 14、分钟菜单选择 30，绑定得到 14:30；流式完成后的输入框实例和焦点仍保留，表单可提交到同一会话，历史包含五个字段。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-calendar-editor-regression.py`：日程编辑器校验通过。该脚本现在编译实际 App 共享组件及其依赖，避免加入设置组件后旧短清单缺少依赖；使用与回复回归一致的 whole-module 编译方式。
- `python3 App/Tests/check-localization.py`：154 个 Swift 文件通过。
- `git diff --check`：通过。

新增时分菜单后，回归最初把第一个原生菜单误认为会议时长；修正为按时长菜单的选项数定位后重跑通过。不将失败尝试记为通过。

已检查实际原生窗口中的 14:30、深浅色和窄窗口显示：

- [暗色时分选择](../../build/form-time-dark.png)
- [浅色时分选择](../../build/form-time-light.png)
- [窄窗口](../../build/form-time-narrow.png)

截图由实际窗口内容捕获，不代表真实模型的生成耗时验收。测试使用独立临时数据和故意缺失的测试凭据，不调用真实模型、不创建系统日程。图片、日志及测试应用沿用 build/ 忽略规则。

AGENTS.md 无需修改：沿用既有组件、Runtime 和验证入口，没有新增系统访问路径。
