# 恢复关闭 Asky 图标红色

按用户要求，将 `LauncherFunctionIcon.Kind.quit` 从书签橙色恢复为原有 sRGB #FF0000（从 HEAD 的旧 QuitAsky 映射核对）。ToolIconPalette 增加退出红，保留白色 power 图形和现有圆角。README 中英文、设计系统与 App/AGENTS.md 同步为五色规范，取代此前四色记录中退出复用橙色的描述。

- `xcodegen generate` 通过；README 的 Debug xcodebuild 通过，日志 `/tmp/asky-restore-quit-build.log`。
- 实际原生浅色结果窗口截图确认关闭 Asky 图标为红底白色 power：`build/quit-asky-results-NSAppearanceNameAqua.png`。退出回归脚本未全量通过：后续 `QuitSheetMissing`，日志 `/tmp/asky-restore-quit-regression.log`；不据此宣称退出交互通过。
- KulaCore `swift test` 失败：RealRuntimeIntegrationTests.unreachableModelFailsAndProcessIsGone 的 running 状态及 runningPID 两处断言，日志 `/tmp/asky-restore-quit-tests.log`。
- `git diff --check` 通过。构建与截图复用现有 build/ 忽略规则，无新增忽略项。
- README: updated，同步退出红与五色调色板。
- AGENTS.md: updated，App 局部图标规则同步退出红。
- 未提交：目标 LauncherFunctionIcon.swift 在任务开始前已为未跟踪的完整实现，且文档含交叉暂存修改，无法安全提交独立完整改动；保留现有暂存区与其他工作。
