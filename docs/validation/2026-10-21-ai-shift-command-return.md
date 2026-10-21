# 询问 AI 改为 Shift-Command-Return

- 默认组合及设置/动作提示使用 `⇧⌘ ↵`；已保存的旧默认 Cmd-Return、Ctrl-Return 通过现有冲突检查迁移，自定义组合保留。
- README 中英文与 PRD 同步。AGENTS.md 无持久规则变化。

## 实际验证

- `xcodegen generate`：通过。
- README 的 Debug `xcodebuild`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，43 项测试。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --local-shortcuts`：通过。验证两代默认值迁移、自定义绑定保留、Return/数字键盘 Enter 的精确修饰键匹配，以及启动器 Ctrl-Return 不触发、Shift-Command-Return 提交 AI。
- 首次回归发现一处仍使用 Ctrl-Return 的旧派发断言，更新后完整回归通过。
- 查看原生回归生成的 `build/shortcut-edit-light.png`，Ask AI 显示 Shift-Command-Return。截图及构建产物沿用现有 `build/` 忽略规则。
- 未执行主应用的实体键盘端到端验收。
- 本次提交仅包含快捷键变更；任务开始前的设置与固定键盘操作修改保留在工作区。
