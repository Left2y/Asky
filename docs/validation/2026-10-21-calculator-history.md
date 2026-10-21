# 计算历史

## 已实现

- `calc` 或搜索“计算历史”后进入记录列表；指令可在现有搜索指令设置中修改。
- 确认复制本地计算结果时保存表达式和结果，输入过程不保存中间值；同表达式、同结果重新计算置顶去重，最多保留 200 条。记录经 ToolService 保存在本地 SQLite settings 中，重启可恢复，不进入记忆提炼。
- 列表支持按表达式或结果搜索。左侧复制结果；更多菜单提供“基于此继续计算”，将原算式填回普通搜索框，以及使用 `kTextNegative` 的“删除记录”。删除立即刷新并保留相邻选择；空列表显示空状态。
- 入口、输入模式、记录与设置复用计算器 MingCute 图标及现有颜色、窗口和菜单组件。

## 实际执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过；仍有既有 AppUpdater capture、PermissionSettings trailing closure 等警告。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：289 项测试通过。新增测试覆盖持久化重开、去重排序、搜索、删除和 200 条上限。
- `python3 App/Tests/run-launcher-window-regression.py --calculator-history`：亮暗模式通过。覆盖入口、确认复制写入、历史复制不重复写入、继续运算、搜索、negative 删除动作、删除至空列表、返回、重置和自定义指令。
- 查看 `build/calculator-history-NSAppearanceNameAqua.png` 和 `build/calculator-history-NSAppearanceNameDarkAqua.png`：实际原生窗口显示表达式与结果、左侧复制及右侧更多菜单，删除为 negative 色。
- `python3 App/Tests/check-localization.py`：通过。
- `git diff --check`：通过。

首次不带 `DEVELOPER_DIR` 的 `swift test` 使用了 Command Line Tools，因缺少 Testing 模块失败；改用上面的 Xcode 环境后完整通过。未做物理键盘逐键验收或 macOS 15 实机检查。

## 文档与提交边界

README 中英文及 PRD 已同步功能和回归命令。AGENTS.md 无需修改：沿用既有 App、KulaCore 与 ToolService 边界和验证约定。

开始时已有指令菜单、剪贴板和 README 等修改；执行期间暂存区也有外部变化。本次计算动作与既有指令动作共享同一 enum、negative 样式和派发代码，未自动提交，避免把其他任务的改动或不完整依赖写入本次提交。

## 继续计算回填修正

- 根据用户反馈，“基于此继续计算”通过历史记录 ID 读取原始 expression 并填回普通输入框。例如 `12-1 = 11` 回填 `12-1`。
- 原生回归改为断言回填 `2 + 3`，追加 ` * 2` 后结果为 `8`，覆盖原算式和运算优先级的保留。
- 本次执行 `xcodegen generate`、README 中的 Debug `xcodebuild`、KulaCore `swift test`（292 项）及 `git diff --check`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --calculator-history` 首次编译完成，但原生运行截图阶段输入框出现非预期的 `n`，随后测试数组索引越界退出；原因未确定。直接重跑已编译的 `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression --calculator-history`：亮暗模式完整通过。
- 已查看本次重跑生成的亮暗模式历史列表及菜单截图；回填与追加运算由实际 LauncherModel 断言验证，未做物理键盘逐键验收。
- README 中英文和 PRD 已同步回填原算式的说明；沿用现有构建、系统操作与窗口规则，AGENTS.md 无需修改。构建和截图产物由已有 `build/` 忽略规则覆盖。
