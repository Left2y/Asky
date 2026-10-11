# 指令设置页恢复

恢复独立的“设置 › 指令”入口，展示当前启动器的八个网页内置指令和 `>` 终端指令；终端应用与工作目录从“通用”移入该页。固定指令仍不可添加、编辑或删除，原有别名页保留。终端设置存储字段未改变。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：退出码 0。
- `xcodegen generate` 与 README 中的 Asky Debug `xcodebuild`：通过，日志 `/tmp/asky-command-settings-build.log`。
- `python3 App/Tests/run-settings-regression.py`：编译成功；首次运行在切换 `hotkey` 页时因窗口标题尚未更新而失败。未修改实现或断言，重新运行生成的 `build/SettingsRegression.app/Contents/MacOS/SettingsRegression` 后，所有页面的浅色/深色快照、导航及最小窗口检查通过。日志 `/tmp/asky-command-settings-regression-retry.log`。
- 以 `--preview --commands` 启动共用真实 SettingsWindow / SettingsView 的原生回归窗口，经 Orca computer-use 截图检查侧栏“指令”、全部内置指令与终端配置可见；工作目录通过辅助功能设为 `/tmp` 后读回一致。使用临时数据目录，没有修改用户实际设置。
- 检查 `build/settings-light-keywords.png` 和 `build/settings-dark-keywords.png`；离屏缓存截图的侧栏背景为黑色，侧栏与标题以实际窗口截图确认。

未执行终端命令，未打包 Release 或安装应用。构建、回归程序与截图沿用既有 `build/` 忽略规则。

README 中英文和 PRD 已同步新入口。AGENTS.md 保持不变：开发命令、模块边界和持久指导没有变化。
