# 发送按钮禁用态可见性

- 原因：发送按钮使用 `.plain`，并在整个按钮上应用 30% 透明度，箭头与背景一起淡化。
- 修正：使用独立 ButtonStyle，只将圆形背景淡化至 30%，箭头保留 iconInverted 原色；32 pt 尺寸、14 pt 图标和禁用条件不变。
- 已运行：`xcodegen generate`；Debug `xcodebuild`（DerivedData：`build/DisabledSendDerivedData`）；KulaCore `swift test`，均通过。
- 原生检查：运行上述新构建的 Asky，PID 42583。AI 对话空输入时辅助功能显示按钮 disabled，截图中箭头清晰；输入“按钮可见性检查”后按钮启用、背景恢复实色；清空输入后重新 disabled。检查文字已清空，未发送消息。
- 截图为本机临时检查产物，未加入版本控制。浅色窗口已检查，深色外观未现场检查。
- README 与 AGENTS.md 无需修改：本次仅修正既有按钮样式，未改变开发命令、架构或使用流程。
