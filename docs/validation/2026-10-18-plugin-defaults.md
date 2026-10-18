# 插件默认停用验证

日期：2026-10-18。

## 行为

- 全新安装的插件列表为空，不自动安装官方或其他插件。
- 用户手动安装插件后默认停用，手动开启才提供工具、指导与执行适配器。
- 已有插件的启用状态在更新和回退时保留。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：通过，共 262 项 Swift Testing 测试；可选真实 Orca 测试未启用。
- 插件测试覆盖新安装停用、重新读取持久状态、停用时不提供工具/指导/适配器、手动启用、更新保留启用状态，以及执行中停用后更新仍保持停用。
- `git diff --check`：通过。
- 仅修改核心安装默认值及相关测试、文档，未修改 App 界面，无新增构建产物忽略规则；沿用现有 SwiftPM 忽略规则。
- README 中英文及插件文档已同步；AGENTS.md 保持不变，未新增开发命令或改变模块边界。
