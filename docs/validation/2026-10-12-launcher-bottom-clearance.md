# 启动器最后一项底部留白

- 问题：键盘选到最后一个结果时，ScrollViewReader 只保证结果可见，没有滚入内容末尾的 12 pt 留白；选中背景贴到窗口边缘并被圆角裁切。
- 修复：将底部留白作为独立滚动锚点，选中最后一个可见结果时滚动到该锚点底部。保留行尺寸、列表高度预算和普通结果的滚动行为。
- 原生回归：在现有窗口检查中加入文档底部与可视区域底部相差不超过 1 pt 的断言。`--bottom-clearance` 专项覆盖亮暗模式、滚轮正反方向、首尾键盘导航和输入焦点，不运行系统事件投递或异步搜索时序检查。

## 实际执行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 Packages/KulaCore 中）：通过。首次未指定 Xcode 的命令因 Testing 模块不可用失败，指定后通过。
- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过，日志 `build/launcher-bottom-build.log`。
- `python3 App/Tests/run-launcher-window-regression.py --bottom-clearance`：亮暗模式通过，日志 `build/launcher-bottom-focused.log`。
- 完整窗口回归未通过：系统滚轮投递检查失败；首次专项试跑尚包含后续异步时序检查，该检查也失败。上述失败不记为通过，完整套件仍需独立排查。
- 真实应用：停止原 /Applications/Asky.app 进程后，启动 `build/DerivedData/Build/Products/Debug/Asky.app`，确认进程 90244 的可执行路径。通过原生 UI 输入 `kimi` 并连续按 25 次 Down；最后“询问 AI：kimi”处于选中状态，截图显示选中行完整且底部留白为 12 pt，符合用户提供的参考图。未提交 AI 请求。

## 文档维护

- README: updated：中英文同步专项回归命令和覆盖范围。
- AGENTS.md: unchanged：没有新的架构边界或持久开发约定。
- 日志和回归产物沿用现有 `build/` 忽略规则。
