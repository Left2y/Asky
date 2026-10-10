# 单词链接与书签搜索入口验证

## 问题

输入 `kimi` 后，结果中既没有链接，也没有书签入口。原因有两个：
- 链接只识别完整网址或域名，单个单词不会生成链接。
- 本机 Chrome 已登录账号，书签同步保存在 `Default/AccountBookmarks` 中（188 条），而 `Default/Bookmarks` 为空。原实现只读取 `Bookmarks`。

## 变更

- `LinksProvider`：单个 ASCII 单词（2–63 位，由字母、数字或连字符组成，且至少含一个字母）只按已知站点补全。已知站点包括 Chrome 书签和 `ChromeTabsProvider.cachedURLs`（仅读缓存，不查询 Chrome），受 Chrome 数据源开关控制。主机名去掉 `www.` 后，以该词开头即视为匹配，取主机名最短的站点，链接到其根地址。例如 `happy` 匹配 `https://www.happyoyster.com`，`kidfasl` 没有匹配，因此不生成链接。早期实现会把任意单词套成 `https://www.<词>.com`，导致不存在的站点也出现链接，现已移除。中文、纯数字、含空格或下划线的输入不生成链接。
- `ChromeBookmarkService.load`：每个配置文件同时读取 `Bookmarks` 和 `AccountBookmarks`，并按 URL 去重。
- 默认搜索不再检索书签。输入非空且启用了 Chrome 数据源时，结果中显示「搜索书签」入口。选择后进入书签搜索，并保留当前输入。
- 新增内置书签搜索指令 `bm `：`LauncherInputState.bookmarks`。输入框显示 `bookmark` 图标。此模式只检索书签，不显示分组标题和 AI 入口。空输入时按退格或 Esc 退出。`bm` 是保留关键词，不能注册为 URL 关键词。
- 链接与书签结果、书签搜索输入框使用设计提供的 `Link.png` / `Bookmark.png`（`App/Assets.xcassets`，1x 64 px / 2x 128 px），替代 SF Symbols。原图为白底方形、无圆角，已按 macOS App 图标网格重绘：1024 画布中 824 圆角瓷砖（圆角 185）、四周留白 100 并带轻阴影，与应用图标的视觉尺寸和圆角一致。
- 分组顺序：应用、链接、书签、文件、Chrome 标签页……

## 检查

1. `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：133 tests / 27 suites 通过。新增测试覆盖单词按已知站点补全（含无匹配不生成链接）、AccountBookmarks 读取，以及 `bm`/入口进入和退出书签搜索。
2. `xcodegen generate` 后执行 README 中的 `xcodebuild` Debug 构建：BUILD SUCCEEDED。
3. `python3 App/Tests/run-launcher-window-regression.py`：浅色和深色外观均通过。
4. 加入图标后重新执行 xcodegen 和 Debug 构建：BUILD SUCCEEDED，产物包含 `Assets.car`；窗口回归检查再次通过。

## 未验证

未在真实窗口中检查以下内容：「搜索书签」入口的外观、进入书签搜索后的键盘操作，以及真实书签结果的打开。

## 提交前复核

- 2026-10-10：使用完整 Xcode 工具链运行 `swift test`，133 tests / 27 suites 通过。
- `xcodegen generate` 成功；README 中的 Debug `xcodebuild` 命令（带 `DEVELOPER_DIR`）返回 `BUILD SUCCEEDED`。
- `git diff --check` 通过。本次复核未运行真实窗口交互验收。
