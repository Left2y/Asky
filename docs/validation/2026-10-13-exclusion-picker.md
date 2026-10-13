# 排除项使用系统选择面板

添加和编辑排除目录／剪贴板排除应用时，使用 ToolService 提供的 NSOpenPanel，移除文字输入 sheet。目录保存目录名，应用保存从所选 .app 读取的 Bundle ID；沿用原有设置数组和匹配语义，不授予额外访问权限。取消保留原值，重复项不新增。选择缺少 Bundle ID 的应用时提示错误，不保存。

## 实际执行

- xcodegen generate：通过。
- README Debug xcodebuild 命令：BUILD SUCCEEDED。
- Packages/KulaCore 的 swift test：通过，Swift Testing 共 241 项。
- App/Tests/run-settings-regression.py --preview：编译当前 App 源码并打开临时数据窗口。新进程 PID 65085，可执行文件 build/SettingsRegression.app/Contents/MacOS/SettingsRegression。
- Orca 读取和操作此进程的实际窗口：目录“添加”打开系统选择面板；前往 /Users/niallyoung/orca/KulaHere 并确定后，列表回读 KulaHere，未保存完整路径。
- 应用“添加”打开 /Applications 的应用选择面板；选择备忘录后，列表回读 com.apple.Notes。
- 点击“编辑 KulaHere”后取消选择，列表仍保留 KulaHere。
- 新构建的 SettingsRegression 可执行文件（无 preview 参数）：原生浅深色设置快照、授权生命周期与卡片拖动恢复回归通过。
- 查看深色实际窗口截图，确认使用系统文件选择面板。未单独验证浅色选择面板、无 Bundle ID 的损坏应用和重复选择场景。

构建和验证 bundle 使用既有 build/ 忽略规则，日志存于 /tmp。仅操作临时设置数据，没有安装或发布。README 中英文补充选择器行为；AGENTS.md 无持久规则变化。工作区原有修改包含本组件及设置调用方，无法把完整任务与原有未提交文件可靠分离，因此未提交，未修改他人的索引。
