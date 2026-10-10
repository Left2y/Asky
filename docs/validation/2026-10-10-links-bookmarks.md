# 链接与书签搜索验证

日期：2026-10-10。

- 新增链接和书签搜索结果分类，复用 SF Symbols `link` / `bookmark`，保持现有 40 pt 图标、64 pt 结果行。
- HTTP(S) 网址及裸域名生成打开链接动作；普通文字、不安全协议、缺失主机和带凭据的网址不生成直接链接结果。域名与文件名可能重合，文件搜索仍并行保留。
- Chrome 本地 Default / Profile 书签按标题或 URL 匹配，遍历嵌套文件夹并按 URL 去重；缺失或损坏文件不阻断其他搜索。遵循 Chrome 数据源开关，无需 Chrome 运行。
- 书签文件读取和 URL 打开在 ToolService 中实现。读取最多 16 个配置，每文件最多 8 MiB，总结果上限 20,000；不读取浏览历史、不访问网站。

实际运行：

1. `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：127 tests / 27 suites 通过，包含工作区已有输入状态测试。新增测试覆盖 URL 识别、嵌套书签、标题/URL 匹配、危险协议过滤、多配置去重、缺失/损坏文件与结果数量限制；书签来自临时测试文件。
2. `xcodegen generate`：成功。
3. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：`BUILD SUCCEEDED`。
4. 使用 `xcrun swift -e` 调用 `NSImage(systemSymbolName:accessibilityDescription:)`：`link` 和 `bookmark` 在当前系统均返回有效图像。

未运行原生窗口视觉检查，也未验证真实 Chrome 书签库、系统默认浏览器实际打开或键盘选择行为。未安装或重启应用。

README 中英文同步新增功能；AGENTS.md 无需修改，现有系统访问边界与验证规则仍适用。
