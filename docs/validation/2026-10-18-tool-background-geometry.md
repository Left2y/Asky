# 修正完整搜索列表中的工具底板圆角

## 复现与修复

用户在 Debug 截图中再次确认，工具底板比网站指令更圆。此前独立组件预览无法覆盖完整列表的实际渲染，先前的“已统一”结论不充分。

在实际 LauncherController / LauncherView 的完整列表夹具中复现：20 pt 工具底板采用 `background(Color)` 后再 clipShape，即使将裁切改为 3 pt 或显式 CGPath，实际轮廓仍偏圆。改为 ZStack 内直接绘制固定 CGPath 圆弧底板，再居中叠加白色图形，移除该颜色背景加裁切的路径；网站品牌与 AI 原图保持原样。

## 实际验证

- Debug xcodebuild 通过，日志 `/tmp/asky-explicit-tool-fill-build.log`；此次修改前已执行 `xcodegen generate`。
- 完整列表浅色、深色原生窗口运行通过，日志 `/tmp/asky-explicit-tool-fill-list.log`。截图 `build/launcher-icon-list-NSAppearanceNameAqua.png`、`build/launcher-icon-list-NSAppearanceNameDarkAqua.png` 已检查：标签页工具现在显示更小的圆弧。
- 对相同 2x 截图坐标测量紫色底板：左边界为 x=62，顶行为 y=184。修复前前九行的着色起点为 `[74,70,68,67,66,65,64,64,63]`；直接绘制后为 `[66,64,63,63,62,62,62,62,62]`，确认完整列表实际轮廓改变，非仅源码参数变化。
- 独立组件深浅色预览也完成，截图复用 `build/shared-icon-tiles-*`。
- KulaCore `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 已执行，RealRuntimeIntegrationTests 的 running 状态与 PID 两项断言仍失败，不记为全量通过；日志 `/tmp/asky-fixed-icon-path-core-tests.log`。
- 已请求重启当前开发版到新构建；未替换安装版。
- `git diff --check` 通过。产物复用 `build/` 忽略规则。
- README: unchanged，现有 3 pt 工具圆角和命令仍准确。AGENTS.md: unchanged，现有组件复用规则仍适用。
- 原有交叉暂存与未跟踪组件均保留，本次无法安全隔离完整依赖，不创建混合提交。
