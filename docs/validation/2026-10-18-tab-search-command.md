# 开启的标签页搜索指令与图标

日期：2026-10-18。

## 变更

- “设置 › 指令”增加“搜索开启的标签页”，默认 `st`，支持触发词冲突检查、自定义保存与恢复默认。
- `st 空格` 进入独立标签页模式，仅调用现有 Chrome 标签页搜索 provider；普通搜索也提供进入该模式的候选，单独搜索 `st` 可选择入口。
- 设置、输入模式及标签页结果均使用用户提供的原始 PNG；资源 SHA-256 为 `1d9428ffc094989f9c30d1a7eebc1bb9623a39aa5960e6c782e5bc183f0d60f4`。

## 实际执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过，日志 `build/tab-command-build.log`。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：264 个测试通过，含标签页指令大小写、空格触发、自定义、原始查询重建及退出；日志 `build/tab-command-tests.log`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --search-commands`：通过，含入口执行、仅返回标签页而排除应用结果、自定义触发词持久化、冲突检查、空输入退格退出及资源加载；日志 `build/tab-command-settings.log`。
- 已人工查看该回归生成的实际 SwiftUI/AppKit 窗口截图：`build/search-commands-light.png`、`build/search-commands-dark.png`、`build/search-commands-minimum.png`、`build/tab-search-light.png`、`build/tab-search-dark.png`。设置行、输入模式及结果行图标显示正常，最小设置窗口未截断新增行。
- 原图与打包资源 SHA-256 一致；`git diff --check` 通过。构建产物、日志和截图复用已有 `build/` 忽略规则。

## 边界

标签页范围隔离使用可控 provider 验证，未在本轮对真实 Chrome 标签页执行切换。未替换已安装应用，未发布 Release。

## 搜索入口排序补充验证

用户截图暴露了多结果场景：单独输入 `st` 时，入口随 Chrome 标签页分组落在快捷指令与应用之后，可见区域内无法找到。现在精确匹配默认或自定义标签页指令时，将入口置于首项；入口使用“搜索指令”分组，与真实标签页区分。

- 再次执行上述 `xcodegen generate`、Debug `xcodebuild`、核心包 `swift test` 均通过；核心包共 264 个测试，日志为 `build/tab-entry-build.log` 与 `build/tab-entry-tests.log`。
- 再次执行 `run-settings-regression.py --search-commands` 通过；注入 8 个应用结果（遵循每个 provider 的 8 条上限）与 3 个快捷指令结果，验证 `st` 及自定义大写 `TABS` 的入口始终为首项，回车进入与仅搜索标签页仍通过。日志为 `build/tab-entry-settings.log`。
- 已查看 `build/tab-entry-light.png`、`build/tab-entry-dark.png`：首屏顶部为带紫色 Logo 的“搜索开启的标签页”，其后才是快捷指令与应用；默认选择入口。
- `git diff --check` 通过。日志、截图与检查清单复用 `build/` 忽略规则；未增加忽略规则。
- README 使用方法未变，保持原文；AGENTS.md 无开发命令或架构约定变化。
