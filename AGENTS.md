# Asky

Asky 是使用 SwiftUI 与 AppKit 构建的 macOS 原生效率入口。各目录的作用和开发命令见 [README](README.md)。

- 产品范围、用户流程和验收以 [V1 PRD](docs/PRD.md) 为准。涉及模块或进程边界时，先读[产品框架与架构大纲](docs/framework.md)，再通过[文档索引](docs/README.md)查阅对应专题。
- 所有系统读写只能经由 `Packages/KulaCore` 中的 ToolService。不要在 App、AgentRuntime 或 MCPBridge 中绕过它直接调用系统接口。
- 修改 Swift 代码后，运行 `cd Packages/KulaCore && swift test`；修改 AgentRuntime 后，运行 `npm test`；修改 App 后，用 `xcodegen generate` 生成工程，再用 `xcodebuild` 构建。如果 `xcode-select` 指向 Command Line Tools，命令前加 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`。
- 浮动玻璃表面（启动器外壳与外侧圆形按钮、筛选菜单、剪贴板、预览）采用 Spotlight 式结构：每个表面独立一个窗口，窗口尺寸等于玻璃外形，`hasShadow = true`，内容经 `WindowSurface.glassContentView` 装入 `NSGlassEffectView`（玻璃与内容层都按圆角裁剪）。不要再加透明留白画布、自绘阴影或 `destinationOut` 挖空：透明包络会被窗口服务器描出偏下黑框，自绘阴影会让浅色玻璃变深；玻璃视图若不裁剪，角落的微弱 alpha 会让系统阴影变成方角黑边。启动器内部的操作条与更多操作圆按钮放在主窗口的底部 overlay，使用 `nativeGlassBackground(style: .clear)` 的系统 Clear 玻璃与轻阴影；列表在其下方渐隐，不另设底栏或子窗口，也不叠加 AppKit 玻璃层。详见 `docs/design-system.md` 的玻璃与阴影一节。
- 只有实际运行过的检查才能记为通过。验证结果写入 `docs/validation/`。开发命令必须来自实际配置，并同步到 README。

- Release 打包使用 README 中的 `scripts/package-release.py` 流程，同时生成首次安装用 DMG 与应用内更新用 ZIP；打包前提交源码并保持工作区干净。
- GitHub Release 版本默认以上一个已发布版本为基准，仅将 `x.x.x` 的第三段（patch）加 1，前两段（major、minor）保持不变；只有用户明确指定时才可改动前两段或使用其他版本号。第三段按整数持续递增，不向前两段进位，例如 `0.0.9 → 0.0.10 → 0.0.11`。
