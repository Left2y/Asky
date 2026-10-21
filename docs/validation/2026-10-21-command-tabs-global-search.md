# 指令设置 Tab 与全局搜索

- 截图指定的 `ql` 行名称为“搜索指令”；沿用 `AppModel.searchCommands` 的统一名称，清理重复本地化键。
- “搜索指令”和“内置指令”改用原生分段 Tab 切换；模块顶部只有一个搜索框，输入时同时显示两组匹配项，清空后回到所选 Tab。
- “编辑快捷指令”清空搜索、切换对应 Tab、滚动并聚焦目标输入框。

实际执行：

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过（43 tests / 10 suites）。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --search-commands`：通过；覆盖实际原生 Tab 切换、唯一全局搜索框、跨组匹配、无匹配、两组编辑入口焦点及既有指令行为。

另以 `--search-commands -AppleLanguages '(zh-Hans)'` 重跑原生回归：通过，中文窗口中 `ql` 行显示“搜索指令”。

已检查新代码运行的原生窗口截图：[搜索指令](../../build/command-tabs-search.png)、[内置指令](../../build/command-tabs-built-in.png)、[全局搜索](../../build/command-tabs-global-search.png)。构建与回归中的既有编译警告仍存在，不影响本次通过。

README 中英文同步了 Tab 和全局搜索行为；AGENTS.md 未变，未引入新命令或架构边界。构建日志、回归截图沿用已有 `build/` 忽略规则。
