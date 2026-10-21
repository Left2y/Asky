# 固定方向键导航

- 从启动器和剪贴板的快捷键设置中移除上一项、下一项、左侧记录和右侧记录配置。方向键继续使用固定默认值，拒绝改键并忽略已保存的方向键覆盖值；剪贴板左右切换记录的既有行为保留。
- README 中英文同步固定方向键的说明。

## 实际检查

- `xcodegen generate`：通过。
- README 的 Debug `xcodebuild` 命令：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，Swift Testing 报告 43 项测试。
- `python3 App/Tests/run-settings-regression.py --local-shortcuts`：首次因设置页被并行任务修改而中止，重跑通过。覆盖方向键禁止改键、旧覆盖值忽略、设置页无方向键录制按钮，以及其他快捷键的保存、录制、冲突和派发。
- 查看新生成的 `build/shortcut-edit-light.png`：原生设置页布局正常；截图仅覆盖页面顶部，方向键配置移除由原生按钮检查验证。未手动端到端操作主应用的方向键导航。
- `git diff --check`：通过。截图沿用现有 `build/` 忽略规则。
- AGENTS.md: unchanged；没有新增持久开发规则。
- 当前设置页和 README 同时包含另一任务的通用分组调整，本任务保留该改动，未创建混合提交。
