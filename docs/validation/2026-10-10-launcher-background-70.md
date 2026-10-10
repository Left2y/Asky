# 搜索框恢复 70% 黑／白底色

用户指出恢复透明玻璃后底色太透明，并明确要求使用原有 70% 黑／白。前一版将 background 变量强制设为不透明，再自定义浅色 48% / 深色 60% alpha，偏离了原有语义变量。

本轮直接使用 `ThemeColor.kBackground.color(for: colorScheme)`，即浅色 Palette/white70、深色 Palette/black70，不再覆盖 alpha。底色独立叠在玻璃光学层之上；保留已有 82% 光学层覆盖、边缘高光和阴影。减少透明度时仍使用不透明背景。未修改搜索行为与布局。

## 实际验证

- `xcodegen generate` 成功。
- README 的 Debug `xcodebuild` 命令加 Xcode `DEVELOPER_DIR`：BUILD SUCCEEDED。
- 相同 Xcode 环境的核心 `swift test`：130 tests / 27 suites 通过。
- 独立红、绿、白条带及文字背景窗口上使用生产 LauncherView / LauncherPanel 检查浅色收起、深色收起及浅色展开；查看桌面合成截图，恢复更明显的白／黑遮罩，背景保留透视。测试使用隔离数据库、局部主题；未修改系统主题设置。
- 重开最终 Debug 构建；未安装或打包 Release。

截图及日志位于沿用既有忽略规则的 `build/launcher-70/`，截图为 `light.png`、`dark.png`、`light-results.png`。前一轮窗口回归的 `initial search must finish` 失败未在本轮重新验证；不将它记为通过。

README: updated，中英文同步 70% 黑／白底色。AGENTS.md: unchanged，开发命令、架构边界与子项目没有变化。已有用户改动保留，提交只包含本次底色修正和相应文档。
