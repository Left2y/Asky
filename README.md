# KulaHere

[中文](#中文) | [English](#english)

<a id="中文"></a>

## 中文

### 项目简介

KulaHere 是一个规划中的 macOS 原生效率入口，采用 SwiftUI 与 AppKit，以快捷搜索和确定性工具为基础，通过 AI、本地记忆和情境提醒增强日常工作流。

仓库已经包含首版代码：原生 App、核心 Swift 包、Pi Agent 宿主和 MCP Bridge，可以构建运行，自动化测试全部通过。DeepSeek 基础对话与历史重开已通过真实模型验证，见 [DeepSeek 验证记录](docs/validation/2026-10-09-deepseek.md)。完整界面流程、真实系统权限及其他模型能力尚未验收，详见 [M0 验证记录](docs/validation/2026-10-09-m0.md)。

### 核心能力

V1 规划包含三个层次：

- 桌面入口：应用、文件、Chrome 标签页、命令、小工具与剪贴板历史。
- AI 增强：自然语言对话、截图理解、系统工具及 Messages 草稿交接。
- 个人上下文：本地记忆与有依据的少量情境提醒。

用户自带模型 API Key，首版优先 OpenAI-compatible Chat Completions，必要上下文按授权外发。Pi SDK 是待原型验证的 Agent 方案：原生入口常驻，明确 AI 请求才启动辅助进程，空闲后退出；后台模型唤醒默认关闭。界面使用用户 Figma 变量与 Styles 和原生 Liquid Glass，资源占用通过有界加载与生命周期管理控制。 聚焦搜索按 [Figma Field 22:348](https://www.figma.com/design/tmVnTyCb2sz5egNQ7We9Sw/Asky?node-id=22-348) 实现为 720 × 64 pt 胶囊输入框，使用原生 Regular Liquid Glass 与 70% 白／黑语义底色，保留定向边缘高光及独立投影；底色与前景随系统主题切换，原生玻璃负责背景适配，减少透明度时使用不透明背景。见[Regular 玻璃验证记录](docs/validation/2026-10-10-launcher-regular-glass.md)；验证范围见[聚焦搜索记录](docs/validation/2026-10-09-figma-search.md)。

完整输入已配置关键词（如 `go`，不加空格）时，匹配命令独立显示在最前面的「别名匹配」组并默认选中；快捷指令组也排在普通应用结果之前。关键词加空格后仍进入查询输入模式。

搜索结果仅在同时存在两个及以上分类时显示组标题；单一分类隐藏标题并释放对应高度。搜索结果按 [Figma 22:364 / 43:1475](https://www.figma.com/design/tmVnTyCb2sz5egNQ7We9Sw/Asky?node-id=22-364) 展示分类标题；菜单项更新为 [Figma Spotlight Item 38:461](https://www.figma.com/design/tmVnTyCb2sz5egNQ7We9Sw/Asky?node-id=38-461) 的 50 pt 结果行、32 pt 图标、14 pt 标题、12 pt 路径和 16 pt 圆角，关键词使用浅色填充标签。见[菜单项验证记录](docs/validation/2026-10-10-search-menu-item.md)。放大镜始终位于输入框右侧；空输入与有输入统一使用 28 pt 左右内边距、64 pt 高度与 18 pt 字号。输入已配置关键词并加空格（如 `go `）后，左侧显示默认浏览器图标，输入框只显示查询正文；空正文时退格或按 Escape 返回普通搜索。自定义关键词（如 `saf`）使用相同样式，需先在设置中配置。普通搜索不检索剪贴板历史；剪贴板独立快捷键与面板待下一份设计。验证范围见[搜索输入与指令状态记录](docs/validation/2026-10-10-search-input.md)。

搜索浮窗顶部位于当前屏幕可用区域高度的 12% 处；搜索列表高度最多为 8 个菜单项的高度（400 pt，分类标题包含在此预算内），同时受当前屏幕可用高度限制，底部与 Dock 保留间距，超出结果滚动展示，隐藏滚动指示条，内容裁切在外壳圆角内。连续输入合并为 100 ms 后的最新查询；关键词模式立即切换，并支持中文输入法的全角空格。见[搜索性能与窗口修复记录](docs/validation/2026-10-10-launcher-height-performance.md)。

鼠标指针位于输入框或结果区时，支持滚轮与触控板滚动结果；滚动保持输入焦点与键盘选择。键盘导航也会将屏外选中项滚入视野。搜索外壳整体接收鼠标交互，输入区与结果区的空白位置也不会将滚动穿透到背景窗口。

独立本地 MCP 与应用共用系统工具，外部接入单独授权，不依赖 Pi。短信最终由用户在 Messages 中发送。

普通搜索中的链接与「搜索书签」入口统一放在「APP 应用」分组，不单独显示链接或书签分类。输入 HTTP(S) 网址或域名可直接打开；启用“Chrome 标签与书签”后，按标题或 URL 检索 Chrome Default / Profile 配置的本地书签，以默认浏览器打开。无需 Chrome 运行，不读取浏览历史。见[链接与书签验证](docs/validation/2026-10-10-links-bookmarks.md)。

“搜索书签”入口使用内置蓝色书签图标；书签搜索结果显示系统默认浏览器的应用图标（例如 Chrome），与打开该链接的浏览器一致。

普通入口中，未输入显式关键词且没有实际本地结果的纯文字（例如“你是谁啊”“你好”）只显示并默认选中 AI，回车进入对话；“搜索书签”和通用 Google 搜索动作不视为本地命中。明确请求继续直接显示 AI；有实际匹配的应用、文件或链接时保留本地结果，显式关键词、计算、换算与 `bm ` 书签模式优先。输入期间不调用模型。AI 条目只显示标题，不显示提交快捷键副标题；普通搜索也可选中 AI 条目后按回车，`⌘ Return` 继续作为快捷提交。

AI 搜索条目使用用户提供的彩色图标，放入 32 pt 图标区域，以白底圆角、轻微投影与留白对齐 App、链接及书签 logo。

### 文档

- [文档索引](docs/README.md)：阅读顺序、权威内容与设计状态。
- [V1 产品需求文档](docs/PRD.md)：已确认范围、用户流程、默认行为与验收。
- [产品框架与架构大纲](docs/framework.md)：技术栈、模块、数据流、进程和接口边界。
- [原生界面与设计系统](docs/design-system.md)：Figma 数据、控件映射与液态玻璃。
- [Agent Runtime](docs/agent-runtime.md)：Pi、扩展、模型与按需进程。
- [原生工具与 MCP](docs/native-tools-and-mcp.md)：系统适配器、权限、确认与回读。
- [数据、记忆与提醒](docs/data-and-memory.md)：持久化、来源、清理与后台调度。
- [资源生命周期与性能](docs/resource-lifecycle.md)：缓存预算、分页、释放与测量。
- [实施与验证](docs/implementation-and-validation.md)：M0–M4 门槛、风险与验收映射。

### 目录结构

- `App/Sources`：菜单栏 App，包括启动器面板、AI 对话、确认面板、设置、剪贴板和情境提醒。
- `App/Assets.xcassets`：App 内置图片资源，例如启动器的链接与书签图标。
- `Packages/KulaCore`：Swift 包，包含 Contracts、Theme、Router、Search、DirectActions、Adapters、ToolService、LocalStore、AgentHost、Memory、Scheduler、Resources、MCPLink、MCPGateway。
- `AgentRuntime`：TypeScript 编写的 Pi 宿主，通过 stdio JSONL 协议 v1 与 App 通信。
- `MCPBridge`：`kulahere-mcp` 的 SwiftPM 包，供测试使用；App 内置的同名二进制由 `project.yml` 构建。
- `project.yml`：XcodeGen 配置。生成的 `KulaHere.xcodeproj` 不纳入版本库。

### 开发与验证

需要 macOS 26、Xcode 26、XcodeGen 和 Node 22 或更高版本。如果 `xcode-select` 指向的是 Command Line Tools，请在命令前加上 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`。

```sh
# Agent 宿主（App 的开发构建从源码目录读取 AgentRuntime/dist）
cd AgentRuntime && npm install && npm run build && npm test

# 核心包测试；需先构建 Bridge，端到端测试才会运行
cd MCPBridge && swift build
cd Packages/KulaCore && swift test

# 构建 App
xcodegen generate
xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/KulaHere.app
```

搜索输入原生编辑器回归检查（完成 App 构建后，在项目根目录运行）：

```sh
xcrun swiftc App/Sources/LauncherSearchField.swift App/Tests/LauncherSearchFieldRegression.swift -o build/launcher-input-regression
build/launcher-input-regression
```

搜索窗口尺寸回归检查（先完成上述 Debug 构建，不与构建同时运行）：

```sh
python3 App/Tests/run-launcher-window-regression.py
python3 App/Tests/run-launcher-window-regression.py --ai-routing
python3 App/Tests/run-launcher-window-regression.py --alias-routing
```

此检查在独立测试窗口和临时数据库中模拟延迟搜索源，采样连续输入期间的窗口高度与输入框位置，覆盖浅深色外观、结果减少、清空与关键词输入，不使用个人数据或真实系统搜索源。滚动穿透回归另起独立进程的可滚动测试窗口，通过系统投递合成滚动事件；此项需要已授予的 macOS 输入事件投递权限，不会自动请求授权。

使用 AI 前，需在“设置 › 模型”中填写 OpenAI 兼容接口的地址、模型名和 Key，Key 保存在钥匙串。设置页不回填 Key，留空保存会保留已有 Key。授权取消、授权失败与 Key 缺失会分别显示原因；完成钥匙串授权后重新发送消息。数据位于 `~/Library/Application Support/KulaHere/`。

AI 对话和设置默认使用普通窗口层级，切换到其他应用后可被覆盖；AI 对话可手动置顶。主动打开时移到当前桌面并一次性请求前台，默认不跨应用持续置顶。再次从 Finder 打开正在运行的 App 会唤起 AI 窗口，最小化的 AI 窗口会先恢复。构建不会替换正在运行的进程，验证改动前需退出旧进程并打开新构建。

AI 对话按 Figma UI 页的新聊天 43:1071、对话 42:760、历史 38:653 实现为 720 × 640 pt 窗口，背景使用与搜索相同的 Regular Liquid Glass。顶部提供历史、新对话、置顶与关闭按钮；默认普通窗口层级，置顶可手动开关。空对话显示居中问候，历史行显示更新时间，正文与输入使用 14 pt 字号，输入框默认高 116 pt。消息支持复制，成功后复制图标变为对勾并保持 3 秒，再次复制会重新计时；复制与附件按钮使用交互悬停色；用户消息气泡与复制按钮之间的空隙也保持悬停。见[新对话样式验证](docs/validation/2026-10-10-ai-chat-refresh.md)。

颜色已同步至 2026-10-10 Figma Colors：浅背景为 6%，输入背景为 8%，搜索结果与历史行使用 Light 6% / Dark 8% 的悬停色。见[颜色同步验证](docs/validation/2026-10-10-colors.md)。

AI 对话输入框支持 `⌘V` 直接粘贴文本、图片或 Finder 文件；点击附件按钮直接打开系统文件选择器，也可拖入文件。附件在输入框顶部横向滚动展示：图片为 1:1 缩略图，文件显示名称与大小；悬停或键盘聚焦删除按钮后可移除。`Return` 发送，`Shift Return` 换行；仅有附件时也可发送。图像理解取决于所配置模型，普通二进制文件的内容解析仍受 Runtime 支持范围限制。

AI 回复通过 MarkdownUI 2.4.1 渲染 Markdown，支持列表、标题、引用、代码块和表格，保留文本选择及明暗主题；历史对话使用相同渲染器。Markdown 图片显示占位符，不自动读取图片地址。Xcode 首次构建会通过 SwiftPM 下载该依赖。见[Markdown 验证记录](docs/validation/2026-10-10-chat-markdown.md)。

系统权限在“设置 › 系统权限”中逐项管理；AI 对话中可用 `⌘,` 或标题右键菜单打开设置。日历、提醒事项和通讯录在首次工具使用时请求授权；拒绝后可打开对应系统设置，返回 App 时自动刷新状态。授权失败的工具行提供“管理权限”入口；授权后需重新发送请求，不自动重放写入。备忘录还需在“数据来源”中添加允许访问的账户和文件夹。

日程、提醒事项、备忘录、通讯录和短信使用 macOS 苹果官方应用及接口。日程结果区分「苹果日历」应用与其中的日历名称（例如「大麦」），不把日历名称当作第三方工具。短信草稿交给苹果「信息」，由用户发送。

创建日程前，AI 可查询实际日历的名称、ID、账户及可写状态。未指定目标时优先使用系统默认可写日历；默认不可用时仅在一个可写日历的情况下自动选择，多个候选则请用户选择。没有可写日历时需先在系统日历 App 中启用账户或创建日历。

DeepSeek 可使用 API 地址 `https://api.deepseek.com`、模型名 `deepseek-flash`。基础对话已验证；工具调用和图像输入仍需分别检查。

首次读取 Key 或重新构建 Debug App 后，macOS 可能要求输入登录钥匙串密码。对话窗口会先显示，授权成功、取消或失败后一次性恢复仍可见的窗口；授权期间已关闭或最小化的窗口不自动重开。配置检查只读取凭据是否存在，不读取 Key。问题与验证范围见[钥匙串与对话窗口验证](docs/validation/2026-10-09-keychain-window.md)和[窗口焦点交接记录](docs/validation/2026-10-10-window-handoff.md)。

<a id="english"></a>

## English

### Overview

KulaHere is a planned native macOS productivity launcher built with SwiftUI and AppKit. Fast search and deterministic tools form its foundation, while AI, local memory, and contextual reminders enhance everyday workflows.

The repository contains the first implementation: a native app, core Swift packages, a Pi agent host, and an MCP bridge. It builds and runs, and all automated tests pass. Basic DeepSeek conversations and reopening saved history have been verified with the real model; see the [DeepSeek validation record](docs/validation/2026-10-09-deepseek.md). Complete UI flows, real system permissions, and other model capabilities still await acceptance; see the [M0 validation record](docs/validation/2026-10-09-m0.md).

### Features

V1 is planned around three layers:

- Desktop launcher: applications, files, Chrome tabs, commands, utilities, and clipboard history.
- AI assistance: natural-language conversations, screenshot understanding, system tools, and draft handoff to Messages.
- Personal context: local memory and a small number of evidence-based contextual reminders.

Users supply their own model API key, with OpenAI-compatible Chat Completions prioritized for V1. Necessary context is sent only with authorization. Pi SDK is the proposed Agent runtime pending prototype validation: the native launcher stays running, while an explicit AI request starts a helper that exits after idle time. Background model wakeups are disabled by default. The interface uses the user's Figma variables and Styles with native Liquid Glass; bounded loading and resource lifecycles govern memory use. Focused search follows [Figma Field 22:348](https://www.figma.com/design/tmVnTyCb2sz5egNQ7We9Sw/Asky?node-id=22-348): a 720 × 64 pt capsule with native Regular Liquid Glass and the 70% white/black semantic background, retaining the directional rim highlight and separate outer shadow. Background and foreground colors follow the system theme, while native glass handles backdrop adaptation. Reduce Transparency uses an opaque background. See the [Regular glass validation record](docs/validation/2026-10-10-launcher-regular-glass.md). See the [focused-search validation record](docs/validation/2026-10-09-figma-search.md) for verification scope.

Typing a complete configured keyword (such as `go`, without a trailing space) places the matched command first in a separate “别名匹配” section and selects it by default. Shortcuts also appear before ordinary app results. A keyword followed by a space still enters query input mode.

Search results show section headings only when two or more categories are present; a single category omits its heading and the corresponding height. Search results follow [Figma 22:364 / 43:1475](https://www.figma.com/design/tmVnTyCb2sz5egNQ7We9Sw/Asky?node-id=22-364), with category headings. Menu items now follow [Figma Spotlight Item 38:461](https://www.figma.com/design/tmVnTyCb2sz5egNQ7We9Sw/Asky?node-id=38-461): 50 pt rows, 32 pt icons, 14 pt titles, 12 pt paths, 16 pt corners, and softly filled keyword badges. See the [menu-item validation record](docs/validation/2026-10-10-search-menu-item.md). The magnifier stays on the right; empty and populated fields share 28 pt horizontal insets, a 64 pt height, and an 18 pt font. A configured keyword followed by a space (such as `go `) shows the default browser icon on the left and only the query text in the field. Backspace with an empty query, or Escape, returns to ordinary search. Custom keywords such as `saf` use the same styling after configuration in Settings. Ordinary search excludes clipboard history; its separate shortcut and panel await the next design. See the [search-input validation record](docs/validation/2026-10-10-search-input.md) for verification scope.

The launcher starts 12% below the top of the current screen’s usable area. The search list is capped at eight menu rows in height (400 pt, including category headings in that budget). It is also limited to the current screen’s available height, leaving clearance above the Dock and scrolling additional results with hidden scroll indicators and content clipped to the shell corners. Rapid typing runs the latest search after a 100 ms debounce; keyword mode switches immediately and also accepts full-width spaces from Chinese input methods. See the [search performance and window fix record](docs/validation/2026-10-10-launcher-height-performance.md).

Mouse-wheel and trackpad gestures over either the input or results scroll the results while preserving input focus and keyboard selection. Keyboard navigation also reveals selected results outside the viewport. The entire search shell accepts pointer interaction, including blank areas in the input and results, so scrolling does not pass through to background windows.

A standalone local MCP shares native tools with the application, requires separate external authorization, and does not depend on Pi. Users send messages themselves in Messages.

Ordinary search groups links and the “Search bookmarks” entry under “APP 应用”, without separate Link or Bookmark categories. Enter an HTTP(S) URL or domain to open it directly. Enabling “Chrome tabs and bookmarks” searches local bookmarks in Chrome Default / Profile configurations by title or URL and opens them in the default browser. Chrome need not be running; browsing history is not read. See the [links and bookmarks validation](docs/validation/2026-10-10-links-bookmarks.md).

The “Search bookmarks” entry uses the bundled blue bookmark icon. Bookmark search results display the system default browser’s application icon (such as Chrome), matching the browser that opens the link.

In the ordinary launcher, plain text without an explicit keyword or concrete local result (such as “你是谁啊” or “你好”) shows only the selected AI action; Return opens the conversation. Generic bookmark-search and Google-search actions do not count as local matches. Explicit requests still show AI directly; matching apps, files, and links remain local results, while explicit keywords, calculations, conversions, and the `bm ` bookmark scope take priority. Typing does not call a model. AI rows show only a title, without a submission-shortcut subtitle. In ordinary search, selecting the AI row and pressing Return also submits it; `⌘ Return` remains available as a shortcut.

AI search entries use the supplied colorful artwork in a 32 pt icon area, with a rounded white background, subtle shadow, and padding aligned with app, link, and bookmark logos.

### Documentation

- [Documentation index](docs/README.md): reading order, authoritative specifications, and design status.
- [V1 product requirements](docs/PRD.md): confirmed scope, user flows, defaults, and acceptance criteria.
- [Product framework and architecture](docs/framework.md): technology choices, modules, data flow, processes, and interfaces.
- [Native interface and design system](docs/design-system.md): Figma data, native controls, and Liquid Glass.
- [Agent runtime](docs/agent-runtime.md): Pi, extensions, models, and on-demand processes.
- [Native tools and MCP](docs/native-tools-and-mcp.md): adapters, permissions, confirmations, and readback.
- [Data, memory, and reminders](docs/data-and-memory.md): persistence, provenance, cleanup, and background scheduling.
- [Resource lifecycles and performance](docs/resource-lifecycle.md): cache budgets, pagination, release, and measurement.
- [Implementation and validation](docs/implementation-and-validation.md): M0–M4 gates, risks, and acceptance mapping.

### Directory Structure

- `App/Sources`: the menu bar app, including the launcher, AI conversation, confirmations, settings, clipboard, and contextual reminders.
- `App/Assets.xcassets`: bundled app images, such as the launcher link and bookmark icons.
- `Packages/KulaCore`: the Swift package containing Contracts, Theme, Router, Search, DirectActions, Adapters, ToolService, LocalStore, AgentHost, Memory, Scheduler, Resources, MCPLink, and MCPGateway.
- `AgentRuntime`: the TypeScript Pi host, communicating with the app over stdio JSONL protocol v1.
- `MCPBridge`: the SwiftPM package for testing `kulahere-mcp`; the app's bundled executable is built by `project.yml`.
- `project.yml`: XcodeGen configuration. The generated `KulaHere.xcodeproj` is excluded from version control.

### Development and Verification

Requires macOS 26, Xcode 26, XcodeGen, and Node 22 or later. If `xcode-select` points to the Command Line Tools, prefix the commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

```sh
cd AgentRuntime && npm install && npm run build && npm test
cd MCPBridge && swift build          # needed for the bridge end-to-end test
cd Packages/KulaCore && swift test
xcodegen generate
xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/KulaHere.app
```

Native search-field regression check (run from the project root after building the app):

```sh
xcrun swiftc App/Sources/LauncherSearchField.swift App/Tests/LauncherSearchFieldRegression.swift -o build/launcher-input-regression
build/launcher-input-regression
```

Search-window geometry regression (after the Debug build above; do not run concurrently with a build):

```sh
python3 App/Tests/run-launcher-window-regression.py
python3 App/Tests/run-launcher-window-regression.py --ai-routing
python3 App/Tests/run-launcher-window-regression.py --alias-routing
```

The check uses a separate test window, a temporary database, and delayed synthetic providers. It samples window height and input position during typing and covers light/dark appearances, fewer results, clearing, and keyword input without using personal data or live system search providers. The scroll-through regression launches a separate process with a scrollable test window and posts synthetic scrolling through the system. It requires existing macOS input-event posting permission and never requests authorization automatically.

Before using AI, enter the endpoint, model name, and key of an OpenAI-compatible API under Settings › Model. The key is stored in the Keychain. Settings does not populate the key field; saving it blank preserves the existing key. Authorization cancellation, authorization failure, and a missing key report separate reasons; resend the message after completing Keychain authorization. App data lives in `~/Library/Application Support/KulaHere/`.

Both AI conversation and Settings use the normal window level by default, so other applications can cover them when you switch. AI conversation can be pinned manually. Explicitly opening a window moves it to the current desktop and requests the foreground once; it does not stay above other applications unless pinned. Reopening the running app from Finder brings up the AI window and restores it if minimized. Building does not replace a running process; quit the old process and open the new build before checking changes.

AI conversations follow the updated Figma new chat 43:1071, conversation 42:760, and history 38:653 in a 720 × 640 pt window, using the same Regular Liquid Glass background as search. The header provides history, new chat, pin, and close controls; the window uses the normal level by default, with optional pinning. Empty chats show a centered greeting, history rows show update dates, and body text and input use 14 pt type with a default 116 pt composer. Messages can be copied; a successful copy shows a checkmark for 3 seconds, and copying again restarts the timer. Copy and attachment buttons use the interaction hover color. Hover remains active across the gap between a user bubble and its copy button. See the [updated conversation validation](docs/validation/2026-10-10-ai-chat-refresh.md).

Colors follow the 2026-10-10 Figma Colors update: subtle backgrounds use 6% opacity, input backgrounds use 8%, and search results and history rows use a hover color at 6% in Light mode and 8% in Dark mode. See the [color synchronization validation](docs/validation/2026-10-10-colors.md).

The AI composer accepts text, images, or Finder files directly with `⌘V`. Clicking the attachment button opens the system file picker directly; files can also be dropped. Attachments scroll horizontally above the text: images use square thumbnails, and files show their name and size. Hover or focus the delete button with the keyboard to remove an attachment. `Return` sends and `Shift Return` inserts a newline; attachments can also be sent without text. Image understanding depends on the configured model, and binary file parsing remains limited by Runtime support.

AI replies use MarkdownUI 2.4.1 to render Markdown lists, headings, blockquotes, code blocks, and tables, with selectable text and light/dark themes. Reopened history uses the same renderer. Markdown images display placeholders without loading their URLs. The first Xcode build downloads this dependency through SwiftPM. See the [Markdown validation record](docs/validation/2026-10-10-chat-markdown.md).

Manage individual permissions in Settings › System Permissions. Open Settings from an AI conversation with `⌘,` or the title’s context menu. Calendar, Reminders and Contacts request access on first tool use. After denial, open the corresponding System Settings pane; permission status refreshes when the app regains focus. Failed tool rows offer a permission settings shortcut. Send the request again after granting access; writes are never replayed automatically. Notes also requires an allowed account and folder in Data Sources.

Events, reminders, notes, contacts, and message drafts use official Apple apps and macOS interfaces. Event results distinguish Apple Calendar from the calendar name inside it (such as “大麦”); a calendar name does not identify a third-party tool. Drafts are handed to Apple Messages for the user to send.

Before creating an event, AI can list actual calendar names, IDs, accounts, and write access. Without an explicit target, it uses the writable system default, or the sole writable calendar when the default is unavailable. Multiple candidates require a user choice. If no writable calendar exists, enable an account or create a calendar in the system Calendar app first.

For DeepSeek, use `https://api.deepseek.com` as the API endpoint and `deepseek-flash` as the model name. Basic conversations have been verified; tool calling and image input still require separate checks.

macOS may request the login Keychain password when first reading the key or after rebuilding the Debug app. The conversation window appears first and restores its foreground position once after successful, cancelled, or failed authorization if still visible; windows closed or minimized during authorization are not reopened automatically. Configuration checks inspect whether the credential exists without reading the key. See the [Keychain and conversation-window validation record](docs/validation/2026-10-09-keychain-window.md) and [window focus handoff record](docs/validation/2026-10-10-window-handoff.md) for verification scope.
