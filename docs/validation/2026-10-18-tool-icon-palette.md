# 自有工具图标固定四色

从现有入口提取并集中为 `ToolIconPalette`：书签橙 #FF9A02、换算青蓝 #0091FF、链接蓝 #2D68FF、标签页紫 #7D40FF。自有工具背景仅允许复用这四种原始颜色，不新增色值或透明度变体。退出复用橙色，计算器复用青蓝色，AI 复用紫色。

实际验证：

- `xcodegen generate` 与 README 中 Debug `xcodebuild` 命令通过，日志 `/tmp/asky-tool-palette-build.log`。
- 实际 `LauncherFunctionIcon` 原生深浅色预览运行通过，并检查七种入口渲染。截图 `build/tool-icons-NSAppearanceNameAqua.png`、`build/tool-icons-NSAppearanceNameDarkAqua.png`；未替换已安装应用。
- KulaCore `swift test` 仍未全量通过：AgentHostTests 的 `unreachableModelFailsAndProcessIsGone` 在运行状态与 PID 两处断言失败，日志 `/tmp/asky-tool-palette-tests.log`。
- `git diff --check` 通过。预览产物使用已有 `build/` 忽略规则。
- README: updated，中英文同步四色限制。
- AGENTS.md: updated，App 范围要求复用固定四色。
- 工作区保留此前未提交与交叉暂存修改，未将它们混入新提交。
