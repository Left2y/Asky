# 指令与工具统一 5 pt 圆角

用户以应用图标为视觉参照，要求快捷指令和工具图标比上一版更圆。

- `LauncherIconTile.cornerRadius` 改为 5 pt；工具半径引用同一个值。网站指令与自有工具共享 20 pt 底板、5 pt 普通圆弧、24 pt 外槽。AI 原图沿用共享裁切；真实应用图标保持系统来源。
- 工具继续直接填充固定圆弧路径，不恢复此前在完整列表中失效的 background 加裁切实现。
- `xcodegen generate` 和 README Debug `xcodebuild` 通过；日志 `/tmp/asky-five-point-icon-build.log`。
- 完整原生搜索列表深浅色运行通过，日志 `/tmp/asky-five-point-icon-list.log`；已检查 `build/launcher-icon-list-NSAppearanceNameAqua.png` 和 `build/launcher-icon-list-NSAppearanceNameDarkAqua.png`。2x 截图工具左边界 x=62，顶行 y=184 的着色起点为 x=70，前十行起点 `[70,67,66,65,64,63,63,63,62,62]`，确认实际轮廓已从 3 pt 变为 5 pt。
- KulaCore `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 已执行，AgentHostTests 的 `unreachableModelFailsAndProcessIsGone` 仍有 running 状态与 PID 两项失败，不记为全量通过；日志 `/tmp/asky-five-point-icon-tests.log`。
- README: updated，中英文同步工具和网站指令 5 pt 圆角；设计系统同步共享参数与直接填色实现。
- AGENTS.md: updated，App 范围参数同步为 5 pt。
- 当前开发版已重启到新构建，PID 7049；`git diff --check` 通过。
- 保留交叉暂存与既有未跟踪文件，完整依赖不能安全归入本任务，未创建混合提交；临时产物复用已有 `build/` 忽略规则。
