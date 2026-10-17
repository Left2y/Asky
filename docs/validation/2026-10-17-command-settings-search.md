# 内置指令列表搜索

- “设置 › 指令”标题下增加搜索框，按缩写、原始名称和当前语言名称即时筛选，忽略大小写与首尾空格；一键清除恢复完整列表，无匹配时显示提示。搜索仅作用于设置列表。
- 保留原有品牌图标和逐项启用复选框，新增文案提供中英文翻译；README 与 PRD 已同步。

## 实际验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过，日志 `build/command-search-build.log`。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，日志 `build/command-search-swift-test.log`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py`：通过内置指令启停、候选与持久化、原生设置窗口浅深色回归，日志 `build/command-search-settings.log`。
- 使用上述脚本生成的 `build/SettingsRegression.app/Contents/MacOS/SettingsRegression --preview --commands` 和 computer-use，在临时数据目录的真实窗口验证：` DS ` 只显示 DeepSeek；`小红书` 只显示 `xhs`；`DeepSeek` 匹配名称；`no-such-command` 显示无匹配提示；点击清除后恢复全部 14 条指令。实际点击筛选后的 DeepSeek 复选框，清除筛选后其关闭状态保留。
- 已查看浅深色完整列表截图和筛选截图，搜索框、清除按钮、单条结果布局正常。截图：`build/settings-light-keywords.png`、`build/settings-dark-keywords.png`、`build/command-search-match.png`、`build/command-search-no-results.png`。
- `plutil -lint` 两种语言的 `Localizable.strings`：通过；`git diff --check`：通过。

## 范围

未替换已安装的 Asky。工作区原有的启动器操作栏、文件复制与相关文档改动保留，验证基于当前工作区。

AGENTS.md: unchanged；未改变架构边界、开发命令或独立子项目。
