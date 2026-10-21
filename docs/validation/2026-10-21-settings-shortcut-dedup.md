# 打开设置快捷键去重

“打开设置”移至“通用”分组，只保留一项录制与恢复默认入口；各窗口继续共用同一个 settings 动作和保存值。

实际检查：
- xcodegen generate：通过。
- README 中 Debug xcodebuild 命令：最终构建通过。
- DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore：通过。
- DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --local-shortcuts：最终运行通过；首次运行因编译期间源文件变化而失败，随后重新运行成功。
- python3 App/Tests/check-localization.py：通过。
- 设置页 localRows 静态检查：settings 仅出现一次，位于独立通用分组。
- 已查看实际 SettingsWindow 回归截图 build/shortcut-edit-light.png，通用分组包含唯一的 Open Settings 入口；未验证真实键盘或替换用户当前应用。
- git diff --check：通过。build/ 截图沿用现有忽略规则。

README: updated，中英文同步通用分组及设置共享配置说明。
AGENTS.md: unchanged，没有新的长期规则或边界变化。

本次改动与工作区并行修改重叠在 SettingsView.swift 与 README.md 的相同行，未创建混合提交；保留其他方向键相关修改。
