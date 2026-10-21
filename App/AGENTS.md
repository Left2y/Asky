# Asky native app

这是 Asky 的 SwiftUI / AppKit 原生界面与窗口生命周期实现。界面规范以[设计系统](../docs/design-system.md)为准，开发与原生回归命令见根目录 README。

系统操作交给 KulaCore 的 ToolService；插件页面只管理宿主提供的安装、配置与启停接口，不直接执行插件或 CLI。视觉判断使用新构建的实际窗口，不能仅以构建通过代替。

自有工具入口图标必须复用 `LauncherFunctionIcon`，采用 MingCute 白色矢量图形、`ToolIconPalette` 统一色板纯色底板（退出使用原有红色 #FF0000）与 5 pt 普通圆角，背景色集中在共享色板中维护；新增和修改图标前先查[设计系统的图标规范](../docs/design-system.md)，不得改回预合成 PNG 或超椭圆。

AI 入口保留既有 `Agent` 品牌图，不适用 MingCute 纯色工具图标规范；未经用户明确要求不得替换。
