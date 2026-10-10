# AI 回复 Markdown 渲染验证

日期：2026-10-10。

## 原因与修复

原来的回复使用 `Text(LocalizedStringKey(item.text))`，只支持行内 Markdown，截图中的 `-` 列表没有被作为列表布局。助手消息现在使用 `ChatMarkdownView` 和固定版本 MarkdownUI 2.4.1，实时回复及历史重开共用同一入口；用户气泡、工具状态与错误行保留原实现。

正文保持 16 pt 字号与语义主题色。支持列表、嵌套列表、标题、引用、链接、代码块和表格，代码块可横向滚动，文本可选择。块级及行内图片使用不读取 URL 的占位提供器，不因模型输出发起图片网络请求或本地文件读取。依赖通过 `project.yml` 的 SwiftPM 配置接入。

## 已运行检查

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：117 tests / 23 suites 通过。这是核心回归检查，并非 App Markdown 单元测试。
- `xcodegen generate`：生成成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- 独立 SwiftUI / NSHostingView 离屏渲染：复用实际 `ChatMarkdownView`，检查截图中的中文四项列表，以及标题、嵌套列表、粗体、引用、代码块与表格。浅色、深色均可见项目符号和结构化排版，代码块保留等宽文本。临时脚本和截图位于 `/tmp/kulahere-render-markdown.py`、`/tmp/kulahere-markdown-{light,dark}.png`，不纳入版本库。

## 验证边界

未重启用户当前运行的 App，未进行新模型请求、链接点击、键盘选择或真实玻璃窗口交互检查。离屏检查不等同于实际窗口端到端验收。构建提示 CoreSimulator 版本不匹配，但 macOS App 构建成功。

README 已同步中英文 Markdown 能力、依赖下载与图片占位行为；AGENTS.md 不变，本次修复没有新增模块边界或开发命令。
