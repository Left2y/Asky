# 剪贴板清空全部验证

卡片与列表更多菜单新增“清空全部”，经 `AppDialog` 的原生 NSAlert sheet 确认。确认正文说明包含固定记录、无法恢复、原始文件保留。取消保留全部历史；确认以事务删除全库记录和全文索引，随后清理历史自有图片与缩略图。清空范围不受当前搜索或 100 条展示上限限制。确认期间暂停失焦隐藏及外部点击关闭，避免父窗口被隐藏。

已执行：

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，包含清空 125 条文本、固定图片、文件记录、全文索引以及清空后重新记录的测试。最初未指定 Xcode 的调用因找不到 Testing 模块失败，指定上述开发目录后通过。
- `python3 App/Tests/check-localization.py`：通过，143 个 Swift 源文件。

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --clear-all`：通过。在实际卡片和列表窗口分别验证取消保留 127 条记录、确认删除全部历史（含固定项及当前搜索之外的记录）、清理图片和缩略图、保留原始文件、窗口保持显示。运行使用独立临时数据库。
- 实际截图已检查：[列表确认](../../build/clipboard-clear-all-list.png)、[卡片确认](../../build/clipboard-clear-all-cards.png)。系统原生 sheet、红色破坏性确认按钮与取消按钮沿用项目样式。截图为当前深色外观，浅色未单独验收。

原生回归首次运行发现 sheet 接管焦点导致未固定面板隐藏，已在失焦关闭条件中排除确认期间，再次构建及回归通过。编译期间改动测试说明文字曾导致一次输入文件变更失败，重新编译后通过。

README 中英文同步行为和原生回归命令；AGENTS.md 无需调整，现有边界与开发流程不变。构建与截图沿用已忽略的 `build/`，无新增忽略规则。
