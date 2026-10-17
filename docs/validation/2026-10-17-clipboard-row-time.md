# 剪贴板历史列表显示复制时间

- 列表行副标题使用记录的 `createdAt` 替代来源应用名，沿用详情区的本地化年月日、时分格式；保留现有字号、颜色与单行布局。
- 已运行 `xcodegen generate` 与 README 的 Debug `xcodebuild` 命令，构建成功。
- 已运行 `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，退出码 0，全部测试套件通过。
- 已运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts`，布局切换、选中保留、搜索、固定、复制与持久化回归通过。
- 已查看新构建实际窗口截图 `build/clipboard-layout-list-text.png`：文本与图片历史项下方均显示日期和时分，副标题完整可见。
- README 中英文说明已同步；未引入新命令或架构边界，AGENTS.md 无需调整。
