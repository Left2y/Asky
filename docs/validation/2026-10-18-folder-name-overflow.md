# 文件夹范围名称溢出

日期：2026-10-18。

- 文件夹图标和名称的组合区域最大宽度为 180 pt，高度为 24 pt；名称保持单行，超长时在末尾显示省略号。
- 悬停仍显示完整目录路径，辅助功能标签保留完整路径。
- `xcodegen generate`、README 中的 Debug 构建命令、核心包 `swift test`（267 项）及本地化检查均实际通过。
- 为原生目录回归增加 `--folders --long-folder-name` 场景，使用中英文混合长名称；检查单行输入框宽度至少为 300 pt，高度不超过 26 pt。
- 最终通过的原生几何检查使用 `build/FolderSourceSnapshot` 与 `build/FolderDerivedData` 的冻结源码和依赖，通过 `build/run-folder-snapshot.py --folders --long-folder-name` 执行。该场景固定面板并屏蔽进程内的外部键盘输入，避免并行界面检查改写测试输入；早先受输入干扰的执行不计为通过。
- Aqua、Dark Aqua 均通过，已查看 `build/folder-long-NSAppearanceNameAqua.png` 和 `build/folder-long-NSAppearanceNameDarkAqua.png`：名称末尾省略正确，图标、输入框和窗口布局未被撑开。
- 构建和截图沿用已有 `build/` 忽略规则。

README 操作方式未变化；AGENTS.md 无新增规则。
