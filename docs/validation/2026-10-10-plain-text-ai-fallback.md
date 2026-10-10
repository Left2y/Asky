# 纯文字 AI 兜底与单分类标题

## 行为

普通入口的纯文字没有实际本地匹配时，只显示并默认选中 AI，普通 Return 交给对话。不再依赖“帮我”“怎么”等句式才能进入 AI；通用 Google 搜索动作与“搜索书签”入口不计为本地命中。实际应用、文件、链接等结果仍保留优先顺序；显式关键词、书签模式、计算和换算保持独立。

结果只属于一个展示分类时隐藏组标题，并从布局高度中移除对应空间。两个及以上分类继续显示标题。

## 执行结果

- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：执行了 133 项测试，其中工作区现有 LinksTests.bareWordGuessesDotComSite 失败。当前未提交的 LinksProvider 仅补全已知网站，旧测试仍期待把未知 kimi 猜成 kimi.com。本次未修改链接提供者或该测试。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter RouterTests`：16 项测试通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --ai-routing`：浅色、深色通过。覆盖“你是谁啊”“你好”“随便聊聊”“我今天有点累”“明天有什么安排”，即时和本地查询结束后均只保留 AI，输入不发送，普通 Return 交接原文；保留实际应用匹配及显式关键词。
- 原生 SwiftUI/AppKit 测试窗口高度断言：单个 AI 结果为 391 pt（64 pt 输入 + 1 pt 分隔 + 50 pt 行 + 12 pt 底距 + 264 pt 阴影画布），没有 52 pt 分类标题。

专项测试显示窗口时受到活动窗口/输入干扰出现回调断言失败；改为保留原生视图及尺寸计算、隐藏测试面板隔离真实用户输入后，浅深色均通过。主 App 已退出旧进程并重新打开 Debug 构建；电脑使用工具确认新窗口。未发送真实模型请求。最新单分类截图未作为通过证据。

README 中英同步兜底规则和单分类标题行为。AGENTS.md 不变，原有模块边界与开发命令仍适用。构建和回归产物沿用 build/ 忽略规则。
