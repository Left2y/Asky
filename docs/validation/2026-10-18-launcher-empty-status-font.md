# 搜索空结果提示字号

- 启动器状态提示由 12 pt 的 `secondary` 样式改为显式 14 pt 系统字体，覆盖“文件夹中没有匹配项目”等搜索状态提示。
- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过，日志 `/tmp/asky-empty-font-build.log`。
- `Packages/KulaCore` 中的 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：退出码 0，日志 `/tmp/asky-empty-font-swift-test.log`。
- 实际窗口：临时在现有文件夹回归的空结果步骤加入截图，检查 `build/folder-empty-NSAppearanceNameAqua.png`；提示完整显示，无裁切。临时截图代码已恢复，不提交。
- 完整文件夹回归未通过：首次编译遇到并发构建改写 `DirectActions.o`；重试成功运行并取得浅色空结果截图，后续失败于 `leaving during a query must restore original search and discard stale results`。未完成深色窗口检查，不将完整回归记为通过。
- `README: unchanged`：仅提示字号修正，使用流程和开发命令未变。
- `AGENTS.md: unchanged`：未改变架构、模块边界或开发规则。
