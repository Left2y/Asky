# 时间单位按需显示与时长

日期：2026-10-22。支持根据任务只显示需要的小时、分钟、秒钟，避免固定显示小时或把时长当成钟点。

## 协议与实现

- time/duration 字段都可提供 components，例如 `["hour","minute","second"]`、`["minute","second"]`、`["minute"]`、`["second"]`。只显示指定单位；单位必须非空、不重复并按时分秒排序。
- time 为具体时刻，缺省 components 仍为时分，兼容已有 HH:mm；duration 为时长，缺省分秒、初值零。
- 内部各段两位数字，按组件顺序用冒号连接。钟点小时 00–23、分秒 00–59；时长第一段 00–99、后续段 00–59，可表示 90 分钟 30 秒。当前不提供超过两位的时长首段或“天”组件。
- 时长回复显式携带单位；3 分钟 30 秒不会提交成含义不明的钟点。完整时分和时分秒时刻保留 HH:mm / HH:mm:ss。
- 创建日程与聊天共用 TimeComponentsPicker；日程仍默认显示时分，修改时间时仍保留日期并清零秒钟。

## 实际检查

- `xcodegen generate` 和 README 的 Debug xcodebuild 命令：成功。
- Debug `codesign --verify --deep --strict`：通过。
- KulaCore `swift test`：298 项通过；AgentRuntime `npm test`：12 项通过。
- ChatFormParserRegression 编译运行通过：新增时分秒范围、仅时/仅分/仅秒、90 分钟时长、显式单位回复，以及空组件、重复、逆序和未知组件拒绝。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-agent-reply-regression.py --forms-preview --components-preview`：通过。真实菜单选择得到时刻 14:30:45、分秒时长 03:30、仅秒钟 30；未指定的单位没有生成控件。流式完成后的输入与焦点保留、验证、提交、防重复及历史回归通过。
- 同一编译产物运行 `--forms-preview --time-preview`：旧的默认时分选择和 HH:mm 提交回归通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-calendar-editor-regression.py`：通过。
- `python3 App/Tests/check-localization.py`：154 个 Swift 文件通过，中英文增加时长与秒钟文案。
- `git diff --check`：通过。

已查看实际原生窗口的深色、浅色、560pt 窄窗口；三个单位的行可显示，分秒和仅秒钟的行不显示小时。截图为原生窗口内容捕获，不作真实模型生成速度的验收。

- [时分秒、分秒和仅秒钟](../../build/form-components-dark.png)
- [窄窗口](../../build/form-components-narrow.png)
- [浅色](../../build/form-components-light.png)

模型指引、README 中英文、PRD、协议示例和开发命令已同步。未调用真实模型或写入日历。构建、截图和日志继续由既有 build/ 规则忽略；AGENTS.md 沿用现有模块和验证规则，无需修改。
