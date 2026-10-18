# 恢复 AI 原有图标

用户明确要求保留 AI 原图。AI 入口恢复 `Agent` 原始图片、20 pt 显示尺寸、4.5 pt 连续圆角及 24 pt 图标槽，不使用 MingCute sparkles，也不套用 ToolIconPalette。搜索结果、输入模式与指令设置通过同一 `.ai` 分支恢复。此规则取代此前工具图标标准与四色验证记录中将 AI 纳入新样式的描述。

- Debug xcodebuild 通过，最终日志 `/tmp/asky-restore-ai-build-final.log`。
- 使用实际组件的深浅色原生预览运行通过，已检查恢复的品牌图像；截图 `build/tool-icons-NSAppearanceNameAqua.png`、`build/tool-icons-NSAppearanceNameDarkAqua.png`。未替换已安装应用。
- KulaCore swift test 仍有已知 AgentHostTests `unreachableModelFailsAndProcessIsGone` 两项断言失败，日志 `/tmp/asky-restore-ai-tests.log`。
- git diff --check 通过；预览产物复用 build/ 忽略规则。保留交叉暂存修改，未提交。
- README: updated，中英文明确 AI 品牌图例外。
- AGENTS.md: updated，明确未经用户要求不得替换 AI 图标。
