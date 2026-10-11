# Chrome 书签与链接搜索授权

## 原因与验证边界

正常经 LaunchServices 启动的 App 读取 Chrome 数据目录时，返回 Cocoa 257、POSIX EPERM。旧加载器用 `try?` 把目录读取错误变成空数组，导致书签模式只有输入框；单词链接补全也依赖书签中的已知站点，因而同时失效。

终端启动的查询及原生回归进程可以返回同一条书签。它们使用不同的进程访问上下文，核心测试通过不能证明安装版本有权限。未确认历史授权具体在哪次安装或启动后变化，不将本次故障归因于某次升级。

## 最终行为

- “设置 › 系统权限”加入“Chrome 书签与链接搜索”，显示实际检查所得的已授权、未授权、目录不存在或读取失败状态。
- “去授权／重新授权”通过 ToolService 打开系统文件夹选择器，选择 Chrome 文件夹并保存安全作用域书签；不自动确认用户授权，不需要完全磁盘访问权限。
- 未授权或正在检查时，不注册 LinksProvider 和 ChromeBookmarksProvider，不显示链接、书签结果或搜索书签入口；`bm` 不进入书签模式。旧结果的执行也受同一授权状态约束。
- 每次打开启动器异步复查权限；授权后重新打开即可启用两项搜索。书签读取与已知站点链接补全使用同一授权。
- Chrome 标签页沿用独立的自动化授权逻辑；系统读写仍通过 ToolService。只读各 Profile 的 Bookmarks / AccountBookmarks，不读取浏览历史。

## 已运行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore --scratch-path build/BookmarkCoreTests`：全部通过。覆盖授权状态、无效授权书签、保存后重新解析，以及禁用 `bm` 时不消耗关键词。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/BookmarkDerivedData build`：BUILD SUCCEEDED。

- 使用最终 App 源码快照及上述独立 DerivedData 运行启动器回归，参数 `--bookmarks --live-bookmarks`：浅色／深色均通过，覆盖未授权时隐藏两类结果、`bm` 禁用、旧入口不能绕过授权，以及有读取权限时真实 DeepSeek 书签与 Kimi 链接返回。
- 使用同一源码快照运行设置回归，参数 `--permissions-only`：通过；检查浅色／深色设置页快照，Chrome 授权行、状态与按钮完整显示。
- 实际经 LaunchServices 重新启动新 Debug App：未授权时输入 `bm deepseek` 仍为普通文本，不显示书签模式图标和书签结果；输入完整网址只显示既有 AI 回退，不显示“打开链接”。未发送 AI 请求、未打开任何链接。
- 用户通过设置中的选择器确认授权后，再次正常启动的端到端恢复尚待人工确认。测试进程的读取成功不等同于安装 App 已获授权。

## 文档与工作区

README 中英文同步授权入口、未授权禁用规则及回归命令。AGENTS.md 保持不变，未改变模块或系统读写边界。日志、构建和用于防止并行编辑影响编译的源码快照沿用 `/build/` 忽略规则。
