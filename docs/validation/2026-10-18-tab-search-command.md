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

## 四个搜索指令统一入口

进一步复现 `link` 没有对应入口的问题：此前链接与 AI 仅支持触发词后按空格，书签入口未按触发词精确匹配。现以统一的 `search-command` 结果处理 `st`、`bm`、`link`、`ai`：精确匹配默认或自定义触发词时置顶并显示对应 Logo，回车进入空查询模式；不重复显示通用标签页/书签入口。进入 AI 模式本身不会提交模型请求。Chrome 指令仍遵循原有数据源及书签读取授权要求。

实际执行：

- `xcodegen generate` 与 README 中的 Debug `xcodebuild` 命令通过；日志 `build/search-entries-build.log`。
- 在核心包执行 README 中的 `swift test` 命令，264 个测试通过；日志 `build/search-entries-tests.log`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --search-commands` 通过；验证四个默认触发词、四个自定义触发词、大小写、异步应用/快捷指令结果到达后仍置顶、回车进入、空格进入、空查询退格退出、不产生重复入口，以及进入 AI 模式不触发提交。日志 `build/search-entries-settings.log`。
- 已查看 `build/search-entry-{tabs,bookmark,link,ai}-{light,dark}.png` 共 8 张实际窗口截图：四种入口的名称与 Logo 正确、首项选中，`link` 不会选中书签入口。
- `git diff --check` 通过。日志、截图及检查清单复用现有 `build/` 忽略规则。README 中英文与 PRD 同步了回车进入行为；AGENTS.md 无持久开发约定变化。

本轮使用隔离数据及受控 provider 验证，未调用真实 AI、未切换真实浏览器标签，未替换已安装应用或发布 Release。
