# 聊天表单与设置控件统一、复用日程月历

日期：2026-10-22。本记录取代前两次表单样式记录中“输入框和选择器已统一”的视觉结论；前两次只处理输入框，并没有消除选择器默认 bezel 导致的填充差异。

## 实现

- 从设置页抽出真正共用的 `SettingsInputField`，设置与表单都使用它。占位文字也采用统一的语义颜色。
- `SettingsChoice` 的底色、圆角、边框与文本框共同经 `settingsInputSurface` 绘制；内部原生 NSPopUpButton 去掉 bezel，只负责菜单选择和键盘行为。设置与表单同时使用这个共享组件，避免再次产生两套填充。
- 表单复用现有 `SettingsCheckbox` 和 `SettingsButton`，删除重复的聊天专用控件实现。
- 日期行使用创建日程现有的 `calendarEditorRow` 表面，点开直接呈现同一个 `CalendarMonthPicker`。创建日程中原来的行只重命名共享修饰符，视觉参数不变。日期表单不增加开始/结束时间等无关字段。

## 实际检查

- `xcodegen generate` 和 README 中的 Debug `xcodebuild` 命令成功。
- `codesign --verify --deep --strict build/DerivedData/Build/Products/Debug/Asky.app` 通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：298 项通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-agent-reply-regression.py --forms-preview --forms-inspect`：通过。包含真实窗口原生文本编辑、流式完成后的字段/焦点保留、下拉选择、同会话提交、草稿附件保留、防止重复提交，以及窗口截图。新增模式使用窗口原生鼠标事件点击日期行，并捕获实际弹出的月历。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --settings-focus`：退出码 0，深浅色设置页焦点及点击外部结束编辑回归通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-calendar-editor-regression.py`：模型校验通过，包含日期选择保留时间分量。修复该旧脚本缺少 MingCute 源文件和引用旧 AppIcon 资源的问题后重跑成功；没有写入系统日历。
- `python3 App/Tests/check-localization.py`：154 个 Swift 文件通过。
- `git diff --check`：通过。

实际查看 WindowServer 合成截图，而不是只看 `cacheDisplay` 的纯色截图。深色图 `form-glass-bright.png` 的文本框内部像素 (500,590)、下拉框内部像素 (155,708) 均为 RGB (47,47,47)，即 `#2F2F2F`；浅色合成图的 (1000,590) 与 (150,708) 内部像素均为 RGB (212,212,212)。这只是所记录截图的取样值，不承诺玻璃在不同桌面背景上的绝对 RGB 值。

- [实际深色窗口，两类控件底色一致](../../build/form-glass-bright.png)
- [实际浅色窗口](../../build/form-glass-light.png)
- [实际弹出的创建日程月历](../../build/form-calendar-popover.png)

外部 computer-use 读取测试窗口遇到 Accessibility 窗口不可读；后续日期点击由回归进程直接发送原生窗口鼠标事件完成。早期回归尝试也遇到编译输入被修改，以及测试用 Accessibility 协议名错误；以上结论仅来自修正后成功的独立运行。

所有图片、临时检查代码、日志和测试应用均位于既有忽略目录 `build/`。未调用真实模型。README 中英文和设计系统已同步共享组件与日期弹层规则。没有新增子项目、构建入口或系统访问边界，AGENTS.md 保持不变。
