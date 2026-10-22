# 原生单选按钮组

日期：2026-10-22。聊天表单新增 `radio`，保留 `select` 下拉单选与 `multi` 复选框多选。模型指引按场景选择：少量、方便比较的选项优先 radio；选项较多、文字较长或需要节省空间时使用 select。

## 实现

- 使用 AppKit 原生 `NSButton(radioButtonWithTitle:)`，在共享 SettingsStyle 中封装；每组使用独立容器与绑定，不自行绘制圆形选中样式。
- 初始不默认选择；必填 radio 未选中时无法提交。与 select 共用选项规则，拒绝多个答案或未知选项。
- 可随完整字段行流式出现，生成完成后继续保留选择，提交到同一会话。

## 实际检查

- `xcodegen generate`、README 的 Debug xcodebuild：成功；`codesign --verify --deep --strict`：通过。
- KulaCore `swift test`：298 项通过；AgentRuntime `npm test`：12 项通过。
- ChatFormParserRegression 编译运行通过：新增 radio 必填、合法单选、多选拒绝、未知选项拒绝及回复内容断言。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-agent-reply-regression.py --forms-preview --radio-preview`：通过。原生 action 从方案 A 切到 C 后只保留 C；另一组选择“稍后”后 C 仍选中；初始无隐式选中，控件具有 radio 无障碍角色。流式输入、生成完成后的焦点和内容保留、提交、防重复、历史及清理均通过。
- 同一编译产物运行 `--forms-preview`：原有下拉、多选及日期表单回归通过。
- `python3 App/Tests/check-localization.py`：154 个 Swift 文件通过；`git diff --check`：通过。

测试中先发现原生按钮直接查询无障碍角色为未知，已显式设置 radioButton / radioGroup 角色。`performClick` 在本异步 main 测试程序中会触发嵌套事件循环并提前退出；最终检查采用原生 action 派发，且确认日志到达末尾成功标记，未把早退当成通过。

已查看新窗口的深色、浅色和 560pt 窄窗口内容截图，单选圆形、选中状态与多组布局可见：

- [深色](../../build/form-radio-dark.png)
- [浅色](../../build/form-radio-light.png)
- [窄窗口](../../build/form-radio-narrow.png)

本次未调用真实模型，未做物理鼠标或键盘导航验收。README 中英文、PRD、运行时协议和开发命令已同步。AGENTS.md 沿用现有模块与验证规则；构建、截图和诊断日志复用已有 build/ 忽略规则。
