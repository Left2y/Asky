# 指令页横向搜索栏

搜索框在左，分类 Tab 在右，间距 24 pt；两者使用 28 pt 高度，搜索框占满剩余宽度。沿用原生分段控件及全局搜索行为。

实际执行：

- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：43 tests / 10 suites 通过。
- 完整 `--search-commands` 回归尝试两次，分别在旧的启动器异步检查 298、357 行失败，未运行到设置布局验证；不记录为通过。
- 新增 `--command-layout` 直接运行实际设置窗口的既有指令页检查，避免先运行不相关的启动器检查。覆盖 Tab 切换、跨组搜索、无匹配及编辑聚焦。使用 `build/command-layout-snapshot` 固定源码快照及原有 DerivedData 运行，实际通过；源码并行修改导致的中途编译作废未记为通过。
- 已检查[最终中文窗口](../../build/command-tabs-search.png)：搜索框在左、Tab 在右，高度一致，24 pt 间距。

README 中英文同步横向布局与定向回归命令。AGENTS.md 不变，本次不改变开发边界。日志和截图沿用已有 `build/` 忽略规则。
