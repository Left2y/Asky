# 搜索入口共享圆角

- 原因：网站品牌、自有工具、AI 各自定义裁切；AI 仍为 4.5 pt 连续圆角，其余为 4 pt 普通圆角。截图所在运行实例无法仅凭图片确定；检查时安装版与开发版同时运行。
- 新增 `LauncherIconTile`，集中 20 pt 外形与 4 pt 普通圆弧圆角；`CommandIcon` 与 `LauncherFunctionIcon` 均调用 `launcherIconTile()`。品牌原图、工具颜色和图形、24 pt 外层槽保持原值。
- `xcodegen generate` 与 README Debug `xcodebuild` 命令通过，日志 `/tmp/asky-shared-icon-tile-build.log`。
- 用实际 SwiftUI 组件与新构建 Assets.car 展示全部 14 个网站品牌、6 个工具及 AI，在原生 NSWindow 中检查深浅色截图：`build/shared-icon-tiles-NSAppearanceNameAqua.png`、`build/shared-icon-tiles-NSAppearanceNameDarkAqua.png`。轮廓一致，品牌图原样保留。未替换安装版，也未重启正在运行的实例。
- 首次 `swift test` 使用 Command Line Tools，因缺少 Testing 模块失败；改用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 后完成运行，仍有 RealRuntimeIntegrationTests.unreachableModelFailsAndProcessIsGone 的 running 状态与 PID 两项断言失败。全量测试不记为通过。日志 `/tmp/asky-shared-icon-tile-tests-xcode.log`。
- `git diff --check` 通过；预览产物复用 `.gitignore` 中已有的 `build/` 规则。
- README: unchanged，现有 20 pt、4 pt 几何描述仍准确；本次收敛实现入口，不改变用法与开发命令。
- AGENTS.md: unchanged，现有图标组件与设计系统约束仍适用。
- 未创建提交：`LauncherFunctionIcon.swift` 在任务开始时已是用户未跟踪文件，且其调用端、资产、规范存在交叉暂存修改；完整依赖不能安全归为本任务，保留原索引与既有修改。
