# 基础键盘操作不提供改键设置

- 方向键、Return 执行/粘贴/发送、Tab 进入文件夹、Backspace 返回、Esc 关闭/返回、Shift-Return 换行作为固定操作，不出现在快捷键配置中。忽略旧改键值并拒绝重新配置。
- 启动器分组只保留询问 AI、更多；剪贴板分组保留复制、删除、更多；AI 分组保留新对话、历史、关闭窗口。
- README 中英文同步；AGENTS.md 无持久规则变化。

## 实际验证

- `xcodegen generate` 与 README 的 Debug `xcodebuild`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，43 项 Swift Testing 测试。
- `python3 App/Tests/run-settings-regression.py --local-shortcuts`：通过，验证固定操作不可改键、忽略旧覆盖值、无对应录制按钮；原生录制与保存、其他快捷键派发、Return 发送及 Shift-Return 换行通过。
- 查看生成的深色原生设置截图 `build/shortcut-edit-dark.png`，启动器仅显示询问 AI 和更多。截图沿用现有 build/ 忽略规则。
- GUI 读取确认重启前主应用仍显示旧列表；退出旧进程并启动新 Debug，进程路径为工作区 build/DerivedData 下的 Asky.app。随后打开主应用设置的 GUI 验证遇到超时和 /Applications/Asky.app 目标变更提示，未将主应用新设置页端到端操作记为通过。
- `git diff --check`：通过。工作区仍有其他任务对同一设置页、README 和剪贴板模块的并行修改，未创建混合提交。
