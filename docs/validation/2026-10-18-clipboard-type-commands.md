# 剪贴板类型指令验证

日期：2026-10-18。

移除剪贴板输入栏的筛选按钮、菜单及其子窗口。`img`（图片）、`text`（文本）、`video`（视频）、`file`（文件）加空格进入互斥类型模式；输入完整指令后也可在结果上回车或点击进入。模式内输入作为搜索正文，空输入退格或 Esc 退出。卡片与列表共用输入与指令逻辑，类型图标复用 LauncherFunctionIcon。

## 实际运行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `python3 App/Tests/check-localization.py`：通过，141 个 Swift 源文件。
- 原生剪贴板 `--filters` 回归：通过。覆盖图片/文本/视频/文件、100 条较新文本之后的旧分类记录、分类与关键词交集、大小写指令、未知前缀、模式内正文不重新解析、空输入退格、Esc、重新打开重置，以及真实 NSTextField/场编辑器的逐字输入、空格消费和回车进入。

回归脚本原命令为 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --filters`。由于并行任务持续修改相同源码与测试，两次编译被 Swift 的 input file modified 检查中止；最终将当时 App/Sources 和 ClipboardRegression.swift 复制到 `/tmp/asky-type-command-check/`，仅替换脚本的源文件路径，沿用原 Debug 依赖、资源、签名及执行流程，完成固定副本的编译和原生窗口验证。

## 截图检查

已查看当前深色窗口实际渲染截图，确认卡片和列表均无筛选按钮，模式左侧显示对应图标，右侧保留窗口固定按钮；完整指令显示可进入的结果行。

- [列表视频模式](../../build/clipboard-command-list-video.png)
- [卡片视频模式](../../build/clipboard-command-cards-video.png)
- [图片指令结果](../../build/clipboard-command-suggestion.png)

视频分类使用缺失原文件的 mp4 引用，验证无需打开原文件即可保持分类；该截图不作为视频播放验收。浅色与玻璃回退未在本次重新截图。

README 中英文与设计系统已同步。AGENTS.md 无持久规则变化。工作区开始时已有未提交修改，任务期间相同文件继续被并行编辑；未自动提交，以避免混入其他任务内容。截图及编译产物沿用现有 build/ 忽略规则。
