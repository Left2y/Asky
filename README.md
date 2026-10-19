<div align="center">

<img src="App/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" alt="Asky" width="128" height="128" />

# Asky

macOS 原生效率入口，连接本地搜索、剪贴板与按需 AI 助手。<br />
A native macOS launcher for local search, clipboard history, and an on-demand AI assistant.

[![macOS](https://img.shields.io/badge/macOS-15%2B-000000?logo=apple&logoColor=white)](project.yml)
[![Swift](https://img.shields.io/badge/Swift-6.2%2B-F05138?logo=swift&logoColor=white)](Packages/KulaCore/Package.swift)
[![MCP](https://img.shields.io/badge/MCP-Bridge-6A1B9A)](docs/native-tools-and-mcp.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[中文](#中文) | [English](#english)

<img src="docs/assets/demo.gif" alt="Asky demo" width="800" />

</div>

---

<a id="中文"></a>
## 中文

### 简介与功能

Asky 使用 SwiftUI 与 AppKit 构建，搜索和剪贴板可独立使用，AI 助手按需启动。项目仍在开发中，验收状态见[验证记录](docs/validation/)。

macOS 26+ 开启液态玻璃时，搜索、AI 对话与剪贴板整窗背景共用无染色的 AppKit 原生 Regular 玻璃；关闭液态玻璃或启用辅助功能显示选项时保留对应回退。

- **搜索**：应用、文件、Chrome 标签与书签，支持网页指令、终端、计算和汇率换算。
- **剪贴板**：文本、图片和文件历史，支持搜索、预览与拖放，可切换卡片或列表视图。两种视图均支持按回车粘贴到原应用，`⌘ Return` 始终仅复制并保留面板。列表底栏检测到输入焦点时显示回车粘贴，更多菜单始终提供“复制到剪贴板”，并在有输入焦点时提供“粘贴并保持窗口开启”（粘贴后保留窗口、搜索词与选中项）；明确无输入焦点时显示 `⌘ Return` 复制，普通回车不执行。微信等应用若不提供完整的焦点信息，保留回车粘贴以兼容其自定义输入框。焦点检测及自动粘贴需要辅助功能权限；粘贴时若目标失效，保留复制结果并提示手动粘贴。列表单击选中、双击复制；底栏“更多”（`⌘K`）可删除记录。卡片与列表的更多菜单均提供“清空全部”，确认后删除所有历史（包括固定记录），原始文件保留。卡片保持单击复制，悬停时右上角显示更多操作按钮；右键不打开菜单。
- **AI 与记忆**：OpenAI 兼容接口、附件、对话历史、联网搜索，以及本地 Markdown 记忆；上下文压缩时显示 loading 与状态提示。
- **系统与扩展**：按授权访问日历、提醒事项、备忘录和通讯录，支持情境提醒、可信 GitHub 插件和 MCP。插件默认不安装，手动安装后默认关闭，需要用户开启。官方插件：[飞书](https://github.com/Niall-Young/asky-plugin-lark)、[Orca](https://github.com/Niall-Young/asky-plugin-orca)。

开启“设置 › AI 与工具可使用的来源 › 路线时间（MapKit）”后，AI 可搜索地点并比较驾车、公交、步行耗时，逐段规划当天日程、计算含到场缓冲的建议出发时间。无需地图 API Key；查询会向地图服务发送必要地点，不自动获取当前位置。未指定方式时比较三种交通方式，合理可行的步行、公交优先考虑；机动车方案默认优先考虑打车；仅在用户明确选择且车辆可用时规划自驾，并考虑停车及停车后的步行时间。打车行驶时间与未知的等车时间分开说明。起点或地点有歧义时先补充确认；公交仅提供预计耗时，不提供线路与换乘详情。此能力用于主动对话，不代表后台提醒已自动接入路线耗时。

拖放优先使用目标应用的原生接收；若目标拒绝拖放，但松手位置可识别为输入框，则将该记录复制后粘贴到目标输入框。Esc 取消或拖到非输入区域不会触发补粘贴。飞书文本拖放即使报告已接收，也会核对同一输入框的前后内容；确认未变化才补粘贴，已有变化则保留原生结果。列表与卡片共用该处理；固定窗口也会在补粘贴前释放键盘焦点，投递后恢复显示。该兜底需要辅助功能权限及可用的拖拽事件观察。

卡片与列表顶部共用主搜索样式：整行输入区内保留窗口固定按钮，不显示搜索图标；所有输入均作为普通搜索词，可匹配正文、来源应用和类型名称（如“图片”“微信”“TIFF”），多个词可组合匹配；固定使用无常驻背景的纯图标按钮，底部分割线两侧留白；列表中间竖线在上下留白。主搜索与剪贴板输入区同为 52 pt 高，右侧图标大小与边距一致。

### 安装与使用

[下载 Asky](https://github.com/Niall-Young/Asky/releases)（macOS 15+，Apple Silicon）。打开 DMG，将 `Asky.app` 拖入“应用程序”后启动。安装包已包含 Node.js 和 AgentRuntime；ZIP 用于应用内更新。自动更新默认开启，可在“设置 › 关于 Asky › 软件更新”关闭。

首次启动默认显示菜单栏图标、登录时启动并隐藏 Dock 图标；主题与语言跟随系统，液态玻璃默认开启（受系统版本支持限制）。已有安装保留原设置。可在“设置 › 通用”调整。文件搜索范围与文件夹导航位于“搜索与导航”；剪贴板相关选项位于独立的“剪贴板”页面，样式默认为列表式，已保存的样式选择保持不变。

| 入口 | 用法 |
| --- | --- |
| 搜索 | 从菜单栏打开，输入关键词，方向键选择、回车打开 |
| 分类搜索 | `file 空格` 搜文件、`app 空格` 搜应用、`ql 空格` 搜快捷方式、`sc 空格` 搜快捷指令；也可输入“搜索文件”等命令名称后选中回车；Esc 或空输入退格退出 |
| 文件夹内搜索 | 选中文件夹按 `Tab`，空输入浏览目录，输入文件名搜索当前目录及 Spotlight 已索引的子目录；空输入退格默认返回上一层，可在“搜索与导航”改为退出全部层级；`Esc` 返回上一层 |
| 剪贴板 | `Ctrl + Shift + C` |
| AI 新对话 | `Ctrl + Shift + /` |
| 网页与终端 | `go 关键词`、`ds 问题`（填入后手动发送）、`yt 关键词`、`x 关键词`（X 搜索）、`> pwd` |
| 设置 | 搜索或剪贴板获得焦点时按 `⌘,` |

文件搜索先过滤隐藏项和排除目录，再按文件名匹配度取结果；同名匹配优先于最近修改的部分匹配。普通搜索每个来源最多显示 8 条；通过指令进入应用、文件、快捷方式或快捷指令模式后，保留搜索词重新查询，最多显示该分类的 200 条结果，可滚动查看。

搜索框右侧常驻静态搜索图标，仅作装饰，没有点击、悬停或固定窗口功能；输入前后保持相同布局。搜索结果出现时，玻璃窗口向下平滑展开，列表轻微淡入；输入框保持原位，并适配系统“减少动态效果”。

搜索和剪贴板列表底栏的“更多”（`⌘K`）在 macOS 26+ 开启液态玻璃时原位变形成菜单，关闭后缩回按钮；旧系统保留材质回退，系统“减少动态效果”开启时立即切换。菜单支持方向键、回车与 Esc，保持搜索词和输入焦点。

单位换算与汇率换算共用横向双卡片，分别显示输入值与目标值，中间以双向箭头连接；卡片只读，不提供选中、悬停或复制操作。

四个分类触发词可在“设置 › 指令”修改并恢复默认。

网站指令默认仅开启 `go`、`chat`、`dy`、`tb`、`jd`、`bl`、`gh`、`x`；其余默认关闭，已有启停配置保留。仅提供内置预设，可在“设置 › 指令”中启停或修改触发词，不支持新增自定义网站。

快捷键可在设置中修改；Chrome 搜索与系统工具需要相应授权。完整操作见[使用教程](https://asky.niallyoung2002.workers.dev/docs)。

### AI 配置与隐私

在“设置 › 智能配置”选择模型服务商，填写 API Key 并保存；也可自定义 OpenAI 兼容地址和模型。Key 保存在 macOS 钥匙串，本地数据位于 `~/Library/Application Support/KulaHere/`。

应用没有向作者上传用户数据的接口。AI 消息、附件、所需工具结果及启用的记忆处理内容会发送至你配置的模型服务；联网搜索词发送至 Bing。详见[隐私政策草案](PRIVACY.md)。

### 开发

需要 Xcode 26 / Swift 6.2+、Node.js 22+ 和 XcodeGen。在仓库根目录执行：

```sh
python3 scripts/setup-local-signing.py
(cd AgentRuntime && npm ci && npm run build)
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/Asky.app
```

常用检查（先构建 MCP Bridge，再测试核心包）：

```sh
(cd AgentRuntime && npm test)
(cd MCPBridge && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build)
(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)
(cd Packages/KulaCore && ASKY_LIVE_MAPS=1 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MapToolsTests)
python3 App/Tests/check-localization.py
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --paste-target
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --clear-all
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --drag-paste-target
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts --more-motion
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts --more-motion --list-drag --pinned-drag
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --website-commands
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --navigation-settings
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --accessories
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --folders
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --file-search
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --filter-search
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --result-motion
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --action-bar --more-motion
```

核心错误与工具说明使用 `CoreLocalization` 及 SwiftPM 共享中英文资源，App 和独立 MCP Bridge 共用；检查规则同时覆盖未接入翻译的固定错误文案。

原生回归、Debug 预览和签名说明见[开发与发布指南](docs/development.md)。发布使用 `scripts/package-release.py` 生成 DMG、更新 ZIP 和校验文件；打包前提交源码并保持工作区干净，沿用固定的 `Asky Local Signing` 证书。检查结果写入 `docs/validation/`。

### 代码与文档

| 目录 | 职责 |
| --- | --- |
| `App/` | SwiftUI / AppKit 原生界面 |
| `Packages/KulaCore/` | 核心能力与统一系统访问入口 ToolService |
| `AgentRuntime/` | TypeScript AI 宿主 |
| `MCPBridge/` | 外部工具桥接 |

[文档索引](docs/README.md) · [产品需求](docs/PRD.md) · [架构](docs/framework.md) · [设计系统](docs/design-system.md) · [插件指南](docs/plugins.md)

### 许可证

[MIT](LICENSE)。第三方依赖遵循各自的许可证。

[English](#english) · [返回顶部](#asky)

---

<a id="english"></a>
## English

### Overview and Features

Asky is built with SwiftUI and AppKit. Search and clipboard history work independently; the AI assistant starts on demand. The project is in development; see [validation records](docs/validation/) for acceptance status.

With Liquid Glass enabled on macOS 26+, search, AI chat, and clipboard window backgrounds share untinted native AppKit Regular glass. Disabling Liquid Glass or enabling accessibility display options retains the corresponding fallbacks.

- **Search**: apps, files, Chrome tabs and bookmarks, web commands, terminal commands, calculations, and currency conversion.
- **Clipboard**: text, image, and file history with search, previews, and drag and drop, in card or list view. In both views, Return pastes into the original app; `⌘ Return` always only copies and keeps the panel open. The list footer offers Return to paste when an input is detected, or `⌘ Return` to copy when focus is confirmed to be outside an input; plain Return does nothing in the latter case. More always includes Copy to Clipboard. With an input target, it also offers Paste and Keep Window Open, preserving the window, query, and selection. Apps such as WeChat that do not expose complete focus information retain Return to paste for compatibility with custom editors. Focus detection and automatic paste require Accessibility access; if the target becomes unavailable during paste, the copied content remains available with a manual-paste message. In list view, click to select and double-click to copy; use More (`⌘K`) in the footer to delete a record. Both card and list More menus offer Clear All; confirmation deletes all history, including pinned items, while preserving original files. Cards still copy on a single click and show a More button in the upper-right corner on hover; right-clicking does not open a menu.
- **AI and memory**: OpenAI-compatible providers, attachments, conversation history, web search, and local Markdown memory; context compaction shows a loading indicator and status.
- **System and extensions**: authorized access to calendars, reminders, Notes, and contacts, plus contextual reminders, trusted GitHub plugins, and MCP. Plugins are not installed automatically and remain disabled after manual installation until the user enables them. Official plugins: [Feishu](https://github.com/Niall-Young/asky-plugin-lark) and [Orca](https://github.com/Niall-Young/asky-plugin-orca).

Enable “Travel time (MapKit)” under Settings › sources available to AI and tools to search places and compare driving, transit, and walking estimates in chat. The agent can query each leg of a day’s calendar and suggest departure times with an arrival buffer. No map API key is needed; necessary locations are sent to the map service, without automatically collecting your current location. Without an explicit preference, compare all three modes and favor practical walking or transit options. For motorized travel, consider taxis before self-driving. Plan self-driving only when explicitly chosen and a vehicle is available, accounting for parking and the walk from parking. Distinguish estimated taxi driving time from unknown waiting time. Missing origins or ambiguous places require clarification. Transit provides estimates only, without line or transfer details. This chat capability does not automatically enable route estimates in background reminders.

Dragging first uses the destination’s native drop handling. If it rejects the drop and the release position identifies an editor, Asky copies the record and pastes into that editor. Escape cancellation and non-input regions do not trigger paste. For Feishu text drops that report acceptance, Asky compares the same editor’s contents before and after the drop, pasting only when they remain unchanged; changed contents retain the native result. Lists and cards share this handling. A pinned window releases keyboard focus before the fallback paste and reappears after dispatch. This fallback requires Accessibility access and available drag event observation.

Card and list views share the launcher search style: the full-row input keeps the window pin button and omits the search icon. All input is treated as ordinary search text and matches content, source apps, and type names (such as Image, WeChat, or TIFF); multiple terms can be combined. The pin is an icon-only button without a persistent background. The bottom divider has horizontal insets, and the list column divider has vertical insets. Launcher and clipboard input rows are both 52 pt tall and share the same trailing icon size and alignment.

### Install and Use

[Download Asky](https://github.com/Niall-Young/Asky/releases) (macOS 15+, Apple Silicon). Open the DMG, drag `Asky.app` into Applications, then launch it. Node.js and AgentRuntime are bundled; ZIP packages are for in-app updates. Automatic updates are enabled by default; disable them in Settings › About Asky › Software Update.

On first launch, Asky shows its menu bar icon, enables launch at login, and hides its Dock icon. Theme and language follow the system; Liquid Glass is enabled where supported. Existing installations retain their settings. Change these options in Settings › General. File search scope and folder navigation are in Search & Navigation; clipboard options have their own Clipboard page. Clipboard style defaults to list view; saved style choices are preserved.

| Entry | Usage |
| --- | --- |
| Search | Open from the menu bar, type a keyword, select with arrow keys, press Return |
| Category search | Type `file ` for files, `app ` for apps, `ql ` for quick links, or `sc ` for shortcuts; alternatively find a category search command and press Return. Escape or Backspace on empty input exits |
| Search within a folder | Select a folder and press `Tab`; browse its contents or type a filename to search it and Spotlight-indexed subfolders. Backspace on empty input returns one level by default; choose to exit all levels in Search & Navigation. `Esc` returns one level |
| Clipboard | `Ctrl + Shift + C` |
| New AI chat | `Ctrl + Shift + /` |
| Web and terminal | `go keyword`, `ds question` (prefills; send manually), `yt keyword`, `x keyword` (X search), `> pwd` |
| Settings | Press `⌘,` while search or clipboard has focus |

File search filters hidden items and excluded directories before limiting results, ranking exact filename matches ahead of recently modified partial matches. Root search shows up to 8 hits per source; entering Applications, Files, Quick Links, or Shortcuts through a command reruns the current query for up to 200 results in that category, accessible by scrolling.

A static search icon remains on the right of the search field. It is decorative, with no click, hover, or window-pinning behavior, and the layout stays the same while typing. Search results gently fade in as the glass window expands downward, keeping the input anchored and respecting Reduce Motion.

With Liquid Glass enabled on macOS 26+, More (`⌘K`) in the search and clipboard list footers morphs in place into its menu and contracts back into the button. Older systems retain the material fallback; Reduce Motion switches immediately. Arrow keys, Return, and Escape work without changing the query or input focus.

Unit and currency conversions share two horizontal cards for the input and converted values, joined by a bidirectional arrow. Both are read-only, with no selection, hover, or copy actions.

Customize or reset the four category trigger tokens in Settings › Commands.

Website commands enable only `go`, `chat`, `dy`, `tb`, `jd`, `bl`, `gh`, and `x` by default; the others start disabled. Existing saved choices are preserved. Commands use built-in presets only. Enable or disable them and change their trigger tokens in Settings › Commands; adding custom websites is not supported.

Customize shortcuts in Settings. Chrome search and system tools require the relevant permissions. See the [user guide (Chinese)](https://asky.niallyoung2002.workers.dev/docs) for full instructions.

### AI Configuration and Privacy

Choose a provider in Settings › Model Settings, enter your API key, and save. Custom OpenAI-compatible URLs and models are also supported. Keys stay in the macOS keychain; local data lives in `~/Library/Application Support/KulaHere/`.

The app has no interface for uploading user data to the author. AI messages, attachments, required tool results, and content used by enabled memory processing go to your configured model provider; web search queries go to Bing. See the [draft privacy policy](PRIVACY.md).

### Development

Requires Xcode 26 / Swift 6.2+, Node.js 22+, and XcodeGen. Run from the repository root:

```sh
python3 scripts/setup-local-signing.py
(cd AgentRuntime && npm ci && npm run build)
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/Asky.app
```

Common checks (build MCP Bridge before testing the core package):

```sh
(cd AgentRuntime && npm test)
(cd MCPBridge && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build)
(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)
(cd Packages/KulaCore && ASKY_LIVE_MAPS=1 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MapToolsTests)
python3 App/Tests/check-localization.py
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --paste-target
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --clear-all
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --drag-paste-target
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts --more-motion
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts --more-motion --list-drag --pinned-drag
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --website-commands
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --navigation-settings
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --accessories
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --folders
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --file-search
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --filter-search
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --result-motion
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --action-bar --more-motion
```

Core errors and tool descriptions use `CoreLocalization` and shared SwiftPM language resources in both the app and the standalone MCP Bridge. The checks also reject fixed error text that bypasses localization.

See the [development and release guide](docs/development.md) for native regressions, Debug previews, and signing details. Use `scripts/package-release.py` to produce a DMG, updater ZIP, and checksums. Commit source changes and keep the working tree clean before packaging, retaining the persistent `Asky Local Signing` certificate. Record checks in `docs/validation/`.

### Code and Docs

| Directory | Responsibility |
| --- | --- |
| `App/` | Native SwiftUI / AppKit UI |
| `Packages/KulaCore/` | Core capabilities and unified system access through ToolService |
| `AgentRuntime/` | TypeScript AI host |
| `MCPBridge/` | External tool bridge |

[Docs index](docs/README.md) · [Product requirements](docs/PRD.md) · [Architecture](docs/framework.md) · [Design system](docs/design-system.md) · [Plugin guide](docs/plugins.md)

### License

[MIT](LICENSE). Third-party dependencies retain their own licenses.

[中文](#中文) · [Back to top](#asky)
