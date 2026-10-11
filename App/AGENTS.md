# Asky native app

这是 Asky 的 SwiftUI / AppKit 原生界面与窗口生命周期实现。界面规范以[设计系统](../docs/design-system.md)为准，开发与原生回归命令见根目录 README。

系统操作交给 KulaCore 的 ToolService；插件页面只管理宿主提供的安装、配置与启停接口，不直接执行插件或 CLI。视觉判断使用新构建的实际窗口，不能仅以构建通过代替。
