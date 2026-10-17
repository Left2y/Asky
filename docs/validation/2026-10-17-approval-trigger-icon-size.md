# 审批触发器图标尺寸

- 触发器原为 13 pt、菜单为 15 pt；统一引用 `ApprovalModePicker.iconSize = 16`。触发器图标明确为 16×16 pt，HStack 使用 center 对齐；菜单保留 20 pt 图标列与标题行居中。
- `xcodegen generate` 与 README 的 Debug xcodebuild 命令通过；KulaCore `swift test` 258 项通过。
- 新编译的 AgentReplyRegression `--preview`（PID 81808）实窗确认自动审批触发器图标已放大且和文字居中，菜单图标同为 16 pt，negative 色已显示为红色。
- 预览首次编译因并行构建修改 cmark-gfm.o 失败，重试成功。尝试用坐标切换完全访问时因窗口未保持焦点被拒，未将该次切换记为通过；完全访问触发器的尺寸通过共享代码确认。
- 构建和预览产物复用已有 `build/` ignore 规则。
- README: unchanged，仅现有图标尺寸修正，不影响用法和命令。
- AGENTS.md: unchanged，无持久规则或架构变化。
