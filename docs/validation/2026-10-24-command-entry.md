# 网页指令回车进入

## 改动

精确匹配网页指令触发词时，默认动作进入指令作用域；不再直接打开空查询网址。输入查询词后的动作仍为打开对应 URL。空格进入方式保留，动作栏使用指令名称。README 中英文同步交互说明。

## 已执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `python3 App/Tests/run-launcher-window-regression.py --command-entry`：浅色、深色通过。使用实际 LauncherPanel、搜索框和 NSTextView 输入大写触发词，通过窗口发送 Return 键事件；覆盖全部启用的预设网页指令及 Google 自定义触发词，检查首选项动作、进入作用域、输入框清空、窗口保留、查询 URL、空格进入和空输入退格退出。
- `git diff --check`：通过。

## 验证边界与其他结果

没有执行外部网站打开，也未进行物理键盘或人工视觉验收。查询后的目标 URL 和打开动作通过断言检查。

首次 `--alias-routing` 执行新增检查时，直接调用搜索框代理处理 Return 的方式未通过；改用真实窗口发送键事件。后续一次编译因测试源文件在编译期间被修改而失败，完成修改后重新编译。最终 `--command-entry` 完整通过。

`--alias-routing` 在新增指令检查之后的旧断言“configured shortcut aliases must survive late search batches and remain selected”失败。该用例将 `sc` 设为快捷指令别名，与现有搜索快捷指令入口同名，而入口结果优先；该冲突与本次网页指令进入分支无关，未修改其行为。没有将该综合回归记为通过。

AGENTS.md: unchanged。未改变项目边界、构建命令或持久开发约束。
