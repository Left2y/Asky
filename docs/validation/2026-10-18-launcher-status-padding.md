# 搜索状态提示底部留白

- 状态提示保持 14 pt 字号，上方 8 pt，底部内边距从 8 pt 增加至 16 pt；窗口仍由内容高度决定。
- `xcodegen generate`、README Debug `xcodebuild`、KulaCore `swift test` 均退出码 0；日志位于 `/tmp/asky-empty-status-padding-build.log` 与 `/tmp/asky-empty-status-padding-tests.log`。
- 使用现有文件夹回归临时加入 `--status-only` 截图分支，在空结果步骤后结束本轮检查；临时源码已恢复。首次运行失败于已有的嵌套 Tab 检查，重试同一二进制通过浅色和深色空结果步骤。
- 已检查 `build/folder-status-padding-NSAppearanceNameAqua.png` 与 `build/folder-status-padding-NSAppearanceNameDarkAqua.png`：底部留白增加，文字完整。此为聚焦检查，不代表完整文件夹回归通过。
- 截图与回归产物沿用已有 `build/` 忽略规则。
- README: unchanged：布局微调未改变操作或开发命令。
- AGENTS.md: unchanged：未引入持久开发规则或模块边界变化。
