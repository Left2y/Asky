# 个人记忆图标阴影

- 内置 Asky PNG 不带 Icon Services 的原生投影。来源列表为其底板补充黑色 22% 不透明度、1 pt 模糊半径、向下 1 pt 的阴影，内部标志叠加层不参与投影。
- `xcodegen generate` 与 README 的 Debug `xcodebuild` 命令通过：`build/source-shadow-build.log`。
- KulaCore `swift test`：37 tests / 9 suites 通过，日志 `build/source-shadow-core.log`。
- 设置回归前两次编译分别因并发构建修改 `Memory.o`、并发编辑修改 `AuthorSettings.swift` 而失败。将源码、回归入口及链接目标文件复制到 `build/source-shadow-snapshot`，使用相同回归脚本编译参数和断言重跑成功，日志 `build/source-shadow-settings-snapshot.log`。
- 人工检查该回归生成的浅色、深色原生设置窗口截图 `build/settings-light-sources.png`、`build/settings-dark-sources.png`：浅色底板外缘阴影可见，深色无异常黑边。
- README: unchanged；AGENTS.md: unchanged。仅图标视觉修复，未变更使用方式、开发命令或架构约定。
- 所有临时脚本、源码快照、构建产物、日志及截图沿用已有 `build/` 忽略规则。其他并发修改保留。
