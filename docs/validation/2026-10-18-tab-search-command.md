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
