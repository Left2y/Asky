# 设置输入框点击外部失焦

设置窗口使用 `SettingsEditingWindow`，在分发鼠标按下事件前检查当前文本编辑区域；点击区域外结束编辑，然后照常分发事件。框内选字、输入框之间切换保持原生行为。

已运行：

- `xcodegen generate` 与 README 中的 Debug `xcodebuild`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：通过。
- `ASKY_DERIVED_DATA=build/settings-focus-validation python3 App/Tests/run-settings-regression.py --settings-focus`：通过。使用独立复制的构建产品，实际设置窗口在浅色、深色下均验证框内点击、输入框切换、框外失焦和内容保留。
- 已检查[浅色截图](../../build/settings-focus-light.png)和[深色截图](../../build/settings-focus-dark.png)：外部点击后无残留光标或焦点边框。
- `git diff --check`：通过。

完整 `--search-commands` 回归未通过：首次因并发构建改写 `AgentHost.o` 中断；隔离构建产品后在已有 `missing tab view` 断言中断，未执行到焦点断言。不将该完整回归记为通过。

构建复制目录与截图由既有 `build/` 忽略规则覆盖。
