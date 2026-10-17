# 询问 AI 图标尺寸与圆角

“询问 AI”原先与计算器共用独立的 3 pt padding、6 pt 圆角与自绘阴影，造成 AI 白色底板仅为 18 pt，且圆角比例明显大于相邻功能图标。

AI 改为复用 `LauncherFunctionIcon`：20 pt 可见外框、4.5 pt 连续圆角、24 pt 图标槽，无额外阴影，保留原始 AI 图片。仅用户提供的三个功能图标使用各自归一参数，其他品牌图片使用原始比例与零偏移。计算器回归标准 24 pt MingCute 功能图标与主题前景色。

## 实际验证

- `xcodegen generate` 与 README 的 Debug `xcodebuild`：通过。
- KulaCore `swift test`：262 项通过。
- 提取实际共享视图，通过 SwiftUI ImageRenderer 将书签、链接、关闭、AI 在深浅背景下并排渲染，检查 24/48 pt 大小、外框与圆角一致：`build/ai-icon-shared-geometry.png`。
- 临时原生启动器回归注入 AI、链接与书签结果，将四个功能图标放在同一列表中，深浅色窗口截图与排序、范围检查通过。截图为 `build/quit-asky-results-NSAppearanceNameAqua.png` 与 `build/quit-asky-results-NSAppearanceNameDarkAqua.png`。
- 未复测完整退出确认流程；前次 `QuitSheetMissing` 限制不变。

设计系统已同步。README 不变：使用方式与公开能力没有变化。AGENTS.md 不变：没有新增开发命令或架构边界。临时程序与图片沿用 `build/` 忽略规则；未替换已安装应用。
