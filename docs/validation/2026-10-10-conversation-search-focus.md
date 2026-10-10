# 对话历史搜索焦点修复

## 行为

- 搜索框使用 16 pt 原生单行 NSTextField，移除 SwiftUI 输入文字的额外行距；静态文字和原生 field editor 共用布局。
- 原生 cell 开始选择或编辑时立即隐藏占位文字，无需先输入字符；失焦后恢复空输入的占位文字。
- 点击搜索胶囊外释放 first responder，保留查询；事件继续交给被点击的控件，不拦截历史行操作。
- 点击监听随输入框拆除而移除，不改变启动器搜索或消息输入框。

## 实际检查

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：140 tests / 28 suites 通过。未指定 Xcode 工具链的首次运行缺少 Testing 模块，未计为通过。
- 原生回归：通过。真实 NSHostingView / NSWindow / field editor 下检查聚焦前后 frame 与 drawingRect 相同、输入前立即隐藏占位文字、中文输入更新查询、鼠标事件触发框外失焦、查询保留、重新聚焦。

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/ConversationSearchField.swift App/Tests/ConversationSearchFieldRegression.swift -o /tmp/kulahere-conversation-search-regression
/tmp/kulahere-conversation-search-regression
```

完整 Debug 对话窗口截图已检查：键盘聚焦搜索框时只显示光标，不显示占位文字。框外释放焦点由上述原生鼠标事件回归确认；完整窗口的鼠标自动化多次遇到焦点或坐标投递问题，未把这些调用记为通过。

README 同步中英文行为与回归命令。AGENTS.md 保持不变：未改变模块边界、构建流程或独立子项目。
