# 剪贴板移除筛选

日期：2026-10-18。

移除剪贴板类型筛选状态、类型指令解析、指令候选行与输入栏类型图标。卡片与列表统一使用普通关键词搜索，`img`、`text`、`video`、`file` 及其后续文本均按字面检索。保留窗口固定及已有记录操作，Esc 关闭更多菜单或剪贴板窗口。

## 实际运行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `python3 App/Tests/check-localization.py`：通过，142 个 Swift 源文件。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --search-only`：通过，覆盖两种布局中原类型关键词及带空格正文的字面搜索、Esc 关闭与重新打开后的查询重置。
- `git diff --check`：通过。

已查看新编译原生窗口的[列表](../../build/clipboard-search-only-list.png)与[卡片](../../build/clipboard-search-only-cards.png)截图：输入栏仅保留搜索和窗口固定，无类型筛选入口或类型图标。此次截图为深色；未重新验证浅色与玻璃回退。

README 中英文及设计系统已同步。AGENTS.md 无持久规则变化。构建与截图沿用现有 `build/` 忽略规则。

开始时 ClipboardWindow.swift、ClipboardRegression.swift、README.md、design-system.md 等已有未提交修改，且本次移除直接覆盖其中类型指令部分；无法将完整改动与既有工作可靠隔离，因此未自动创建提交。其他未提交工作保留。
