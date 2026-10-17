# 日程原生下拉选择器

- 开始与结束时间入口使用 AppKit `NSPopUpButton`，系统绘制下拉外观与箭头。
- 下拉内容使用 `NSDatePicker.clockAndCalendar`，日期与时间绑定原来的 Date 值。
- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过。
- `cd Packages/KulaCore && swift test`：最终重跑通过。首次运行缺少 AgentRuntime/dist/src/plugin-runner.js；尝试 npm run build 时因本地缺依赖失败，但 TypeScript 已输出测试所需 runner，随后 Swift 测试通过。AgentRuntime 未修改。
- `python3 App/Tests/run-message-calendar-regression.py`：通过模型有效性与取消回归。
- 独立预览实际窗口确认开始与结束字段均为原生弹出式按钮，包含系统下拉箭头。自动化点击后未捕获菜单内容，未将菜单内日期和时间修改记为通过。
- build/ 与 AgentRuntime/dist/ 使用已有忽略规则。
- 局部控件替换不影响 README 使用说明或 AGENTS.md 规则。已有并行工作中的文档与弹窗生命周期修改保留。
