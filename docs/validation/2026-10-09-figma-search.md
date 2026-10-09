# Figma 聚焦搜索验证

日期：2026-10-09。范围：启动器搜索输入与玻璃外壳。来源：[Asky / Field 22:348](https://www.figma.com/design/tmVnTyCb2sz5egNQ7We9Sw/Asky?node-id=22-348)。本轮读取了该节点的 design context、截图、尺寸和玻璃属性，未写入 Figma。

> 后续实际桌面浮窗暴露了材质合成问题，本记录的 luminosity / Clear / 自定义阴影方案已被[透明浮窗修正](2026-10-09-launcher-compositing.md)替代；输入尺寸与排版仍有效。

## 实现

- 收起尺寸 720 × 60 pt、左右留白 24 / 20 pt、间距 12 pt，放大镜使用原生 `magnifyingglass`、17 pt 字号及 21 × 22 pt 图标槽。
- 输入使用 16/400/Default，提示简化为 “Search”；使用语义提示色与光标色，保留原生输入、焦点、键盘提交和选择行为。搜索框保留中文辅助功能名称。
- 将 `Colors/background` 的 70% luminosity 背景填充与原生 Clear Liquid Glass 分层，不再把背景当作玻璃 tint。使用 0.5 pt 语义边框和黑色 2%、radius 15、y 8 的轻阴影；原生系统负责玻璃折射与边缘光学效果。
- Figma GLASS 的 radius 6、refraction 0.7、depth 30、lightIntensity 0.25、dispersion/splay 0.2 及 LINEAR_BURN / LINEAR_DODGE 内外阴影无法通过系统公开 API 逐项指定。当前是原生映射，不是这些光学参数的像素级复刻。
- 展开后保持已有 32 pt 圆角、540 pt 高度上限；结果图标左边沿保持与输入图标对齐。减少透明度分支保持同一 RGB 不透明底色，并关闭玻璃与装饰阴影。

## 实际运行

| 检查 | 结果 |
| --- | --- |
| `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | 106 项测试、22 个 suite 通过 |
| `xcodegen generate` | 成功 |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build` | BUILD SUCCEEDED |
| 编译生产 LauncherView / LauncherController 的固定数据原生布局探针 | 收起 720 × 60；1 / 3 / 40 / 2 / 0 结果高度 125 / 217 / 540 / 171 / 60，顶部不移动 |
| 最大结果附带状态、末项选择、终端附带状态、隐藏重开 | 高度分别保持 540、540、398、60 pt |
| 原生 Aqua 与 Dark Aqua 固定背景预览 | 实际窗口截图检查完整胶囊、背景色透出、图标与提示排版；深色预览有可见原生光标，辅助功能树确认输入焦点 |
| 浅色输入读回 | AXSetValue 后读回 kimi，焦点仍在搜索框 |
| `git diff --check` | 通过 |

预览直接编译生产视图，用固定数据和渐变背景，不读取用户内容或执行工具。两种外观同时设置 AppKit appearance 和 SwiftUI colorScheme。未在最终 App 上做实际壁纸、输入法、真实搜索结果、VoiceOver、系统减少透明度或提高对比度验收；减少透明度环境值为只读，本轮不修改用户系统设置。布局探针的选择检查不等同于实际键盘输入验证。

日志、探针与预览产物保存在已有忽略目录 `build/figma-search-probe/` 与 `build/`。预览进程在检查后退出，未安装或重启正式 App。

## 文档检查

README: updated — 中英文同步搜索尺寸、Figma 来源和验证链接。设计系统同步最终输入尺寸与背景/玻璃映射。

AGENTS.md: unchanged — 已检查指令层级、独立包及当前构建配置，本轮未改变开发命令或系统工具边界。原有未跟踪验收草稿不属于本次改动。
