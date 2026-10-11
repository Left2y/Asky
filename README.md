<div align="center">

<img src="App/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" alt="Asky" width="128" height="128" />

# Asky

macOS 原生效率入口，连接本地搜索、剪贴板与按需 AI 助手。<br />
A native macOS launcher for local search, clipboard history, and an on-demand AI assistant.

[![macOS](https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&logoColor=white)](project.yml)
[![Swift](https://img.shields.io/badge/Swift-6.2%2B-F05138?logo=swift&logoColor=white)](Packages/KulaCore/Package.swift)
[![MCP](https://img.shields.io/badge/MCP-Bridge-6A1B9A)](docs/native-tools-and-mcp.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[中文](#中文) | [English](#english)

</div>

---

<a id="中文"></a>
## 中文

### 项目简介

Asky 使用 SwiftUI 与 AppKit 构建，提供菜单栏入口、聚焦搜索、剪贴板历史和 AI 对话。搜索与本地工具独立运行；AI 是按需启用的增强能力。

应用、工程与 scheme 统一为 `Asky`，构建产物为 `Asky.app`，MCP 可执行文件为 `asky-mcp`。为兼容现有安装，沿用原有 bundle identifier、数据目录与钥匙串标识。新 MCP 配置使用 `ASKY_MCP_CREDENTIAL` / `ASKY_MCP_SOCKET`；旧环境变量及 App 内的 `kulahere-mcp` 命令路径继续可用。

项目处于开发阶段，仓库包含原生 App、Swift 核心包、TypeScript Agent Runtime 和 MCP Bridge。系统权限、模型兼容性及完整交互流程仍需在实际环境中验收。

### 核心能力

- **聚焦搜索**：搜索应用、文件、Chrome 标签页与本地书签，读取应用自带的本地化名称（含系统应用的 `InfoPlist.loctable`），支持应用别名、网页关键词、计算和换算。
- **剪贴板历史**：独立面板浏览文本与图片，悬停 1.5 秒后显示完整预览，支持固定、删除和键盘选择；授予辅助功能权限后可直接粘贴。
- **AI 对话**：支持 OpenAI 兼容接口、对话历史、图片与文件附件，以及原生 Markdown 排版。Agent 辅助进程按需启动，空闲后退出。
- **系统工具**：通过 ToolService 统一处理系统读写与授权；集成日历、提醒事项、备忘录和通讯录，信息草稿交由系统 App 确认发送。
- **MCP 扩展**：通过独立授权的 MCP Bridge 向外部客户端提供本地工具。

### 快速开始

[下载 Asky 0.0.3](https://github.com/Niall-Young/Asky/releases/tag/v0.0.3)：适用于 macOS 26+、Apple Silicon。解压 ZIP 后将 `Asky.app` 拖入“应用程序”；包内已包含 Node.js 与 AgentRuntime。此测试版使用 ad-hoc 签名，未经 Apple 公证，首次打开可能触发系统安全提示。

需要 macOS 26 或更新版本、Xcode 26（Swift 6.2 或更新版本）、Node.js 22 或更新版本，以及 XcodeGen。

在仓库根目录运行以下命令，构建开发版本：

```sh
(cd AgentRuntime && npm ci && npm run build)
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/Asky.app
```

### 使用方法

- 从菜单栏打开搜索，输入应用名、文件名或网页关键词，使用方向键选择、回车打开。
- `go`（Google 搜索）、`chat`（ChatGPT）、`yt`（YouTube）、`dy`（抖音）、`tb`（淘宝）、`jd`（京东）、`bl`（bilibili）、`gh`（GitHub）和 `>`（终端）是固定内置指令，无需配置，不能添加、修改或删除。可在“设置 › 指令”查看带对应品牌 Logo 的内置指令并配置终端；设置列表、搜索框与指令结果统一使用 24 × 24 pt、6 pt 圆角图标，周围留白透明、不添加底板或描边，`>` 显示当前所选终端的图标。旧的网页关键词配置不再参与启动器路由；输入 `go 内容`、`chat 问题` 或 `yt 搜索内容` 等即可使用。
- 输入英文 `>` 后按空格进入终端模式，例如 `> pwd`；单独的 `>` 或 `>pwd` 保持普通搜索；回车打开所选终端，在配置的工作目录执行命令。在“设置 › 指令 › 终端 › 执行命令的终端”选择已安装的系统终端、iTerm2 或 Ghostty（1.3+），入口与结果显示对应应用图标。输入框为空时按退格退出终端模式；首次使用可能需要授予自动化权限。
- 在“设置 › 通用 › 文件搜索范围”点击“选择文件夹…”，通过系统文件夹选择窗口添加搜索目录。
- 输入 `1+1`，输入框末尾以浅色显示 `= 2`，下方卡片上下显示公式与结果：上方公式左对齐，下方结果右对齐，回车复制结果；长算式最多显示两行并从中间截断，悬停查看全文。输入 `1美元` 或 `100人民币`，下方横向展示输入币种与人民币的换算卡片（人民币输入默认换算为美元），其他币种保持列表显示在卡片下方。输入 `100 USD CNY` 可只查看指定币种。卡片显示旗帜、币种和金额，不提供选中、悬停或复制操作。汇率使用 ECB 日参考数据；断网时使用已有缓存，无缓存则显示不可用。
- 使用 `Ctrl + Option + Command + V` 打开剪贴板面板；可在“设置 › 触发快捷键”中修改快捷键。
- 使用 `Ctrl + Option + Command + /` 直接打开 AI 并开启空白新对话（无需 Shift）；可在“设置 › 触发快捷键 › AI 对话”中录制自定义组合键或恢复默认；正在回复时先取消旧任务。也可从菜单栏打开“AI 对话”，或在搜索中选择 AI 条目后提交。
- 搜索框或剪贴板面板获得焦点时，按 `⌘,` 打开设置。设置窗口采用原生侧边栏导航，右侧显示分组配置列表，并支持调整窗口大小。应用主题位于“通用 › 外观”。
- 在“设置 › 关于 Asky”查看当前版本并点击“检查更新”，应用会读取 GitHub `Niall-Young/Asky` 的最新 Release；版本高于当前版本时可点击“安装更新”：下载 ZIP 并按 `.sha256` 校验、验证签名，Asky 退出后用新版本替换并删除旧版本，再自动重新打开。应用所在目录需可写；临时转移路径运行时需先移到“应用程序”。
- 应用语言位于“设置 › 通用 › 语言”，默认跟随 macOS 首选语言，也可选择简体中文或 English；更改在下次启动时生效。界面翻译使用原生 `.lproj` 资源，macOS 不会自动翻译应用自定义文字；AI 回复和用户内容不受此设置控制。

### 配置与隐私

**Asky 当前版本没有向项目作者上传用户数据的接口。剪贴板、对话、文件与系统资料不会通过应用上传到作者服务器；AI 请求直接发送到你配置的模型服务。** 作者可能收到你主动提交的 Issue、日志或截图，请先脱敏。

详见[隐私政策草案](PRIVACY.md)，包括本机保存、第三方处理和当前删除限制。正式发布前需补全主体、联系方式及应用内告知；状态见[隐私发布核查记录](docs/validation/2026-10-11-privacy-policy.md)。

使用 AI 前，在“设置 › 模型设置”中填写服务商的 API 地址、模型名和 API Key。Key 存储在 macOS 钥匙串中；本地数据位于 `~/Library/Application Support/KulaHere/`。

系统权限在“设置 › 系统权限”中管理，相关工具按需请求授权。辅助功能和屏幕录制点击“去授权”后打开独立的原生玻璃浮窗，并自动打开对应系统权限页。将浮窗中的 Asky.app 卡片拖入列表后开启开关；重新授权时先删除旧条目再拖入。拖动开始时原位卡片隐藏，取消或未被接收时恢复，被接收后保持隐藏。浮窗持续检查当前应用进程的权限，确认授权后自动关闭，并关闭或收起本次权限页；若已切到其他系统设置页，则保留该页面。临时转移路径运行的应用需先移到“应用程序”并重新打开。AI 请求会将提交的消息、附件及所需工具结果发送到配置的模型服务。使用前请确认该服务的数据处理方式。

### 项目结构与文档

| 路径 | 用途 |
| --- | --- |
| `App` | SwiftUI / AppKit 界面、应用资源和原生回归检查 |
| `Packages/KulaCore` | 路由、存储、系统工具、记忆、调度及授权策略 |
| `AgentRuntime` | TypeScript / Node.js Pi 宿主，通过 stdio JSONL 与 App 通信 |
| `MCPBridge` | SwiftPM MCP 桥接程序 |
| `project.yml` | XcodeGen 工程配置 |
| `docs` | 产品、架构、设计与验证文档 |

从[文档索引](docs/README.md)开始阅读。产品范围见 [V1 PRD](docs/PRD.md)，模块与进程边界见[架构大纲](docs/framework.md)。

### 开发与验证

以下命令均从仓库根目录运行。先构建 MCP Bridge，再运行核心包测试：

```sh
(cd AgentRuntime && npm test)
(cd MCPBridge && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build)
(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)
```

完成快速开始中的 Debug 构建后，可运行原生回归检查。部分交互检查需要系统输入事件权限：

```sh
python3 App/Tests/run-launcher-window-regression.py
python3 App/Tests/run-launcher-window-regression.py --command-icons
python3 App/Tests/run-launcher-terminal-regression.py
python3 App/Tests/run-launcher-calculation-regression.py
python3 App/Tests/run-launcher-window-regression.py --ai-routing
python3 App/Tests/run-launcher-window-regression.py --system-app-names
python3 App/Tests/run-launcher-window-regression.py --alias-routing
python3 App/Tests/run-clipboard-regression.py
python3 App/Tests/run-clipboard-regression.py --hover-delay
python3 App/Tests/run-clipboard-regression.py --settings-shortcut
python3 App/Tests/run-settings-regression.py
python3 App/Tests/run-application-language-regression.py -AppleLanguages "(en)"
python3 App/Tests/run-application-language-regression.py -AppleLanguages "(zh-Hans)"
python3 App/Tests/run-agent-reply-regression.py
```

并行构建时，设置回归脚本支持用 `ASKY_DERIVED_DATA` 指定独立的 DerivedData 目录（兼容旧变量 `KULAHERE_DERIVED_DATA`），默认使用 `build/DerivedData`。

原生输入框与快捷键的独立检查：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/LauncherSearchField.swift App/Sources/EditMenu.swift App/Tests/LauncherSearchFieldRegression.swift -o build/launcher-input-regression
build/launcher-input-regression
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/HotKey.swift App/Tests/HotKeyRegression.swift -o build/hotkey-regression
build/hotkey-regression
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/ConversationSearchField.swift App/Tests/ConversationSearchFieldRegression.swift -o build/conversation-search-regression
build/conversation-search-regression
```

检查结果按实际运行情况记录在 `docs/validation/`。自动化检查与真实系统权限、模型和界面验收分别记录。

### 开源协议

本项目采用 [MIT License](LICENSE)，允许使用、修改、分发和商用，也允许闭源衍生版本；分发本软件或其重要部分时，须保留版权声明与许可声明。软件按原样提供，不作担保。

第三方依赖及其附带资源仍遵循各自的许可证；本项目的 MIT 许可不替代它们的授权条款。

[English](#english) · [返回顶部](#asky)

---

<a id="english"></a>
## English

### Overview

Built with SwiftUI and AppKit, Asky provides a menu bar entry point, focused search, clipboard history, and AI conversations. Search and local tools operate independently; AI is an optional enhancement invoked on demand.

The app, project, and scheme are named `Asky`; build products are `Asky.app` and `asky-mcp`. The original bundle identifier, data directory, and Keychain identifiers are preserved for existing installations. New MCP configurations use `ASKY_MCP_CREDENTIAL` / `ASKY_MCP_SOCKET`; legacy environment variables and the bundled `kulahere-mcp` command path remain supported.

The project is under active development. The repository includes the native app, Swift core packages, a TypeScript Agent Runtime, and an MCP Bridge. System permissions, model compatibility, and complete interaction flows still require acceptance testing in real environments.

### Features

- **Focused search**: Find apps, files, Chrome tabs, and local bookmarks, using each app’s localized names (including system app `InfoPlist.loctable` resources), with app aliases, web keywords, calculations, and unit conversions.
- **Clipboard history**: Browse text and images in a dedicated panel with full previews after hovering for 1.5 seconds, pinning, deletion, and keyboard selection. Direct paste requires Accessibility permission.
- **AI conversations**: Use OpenAI-compatible APIs with conversation history, image and file attachments, and native Markdown rendering. The agent helper starts on demand and exits when idle.
- **System tools**: ToolService manages system reads, writes, and authorization. Integrations cover Calendar, Reminders, Notes, and Contacts; message drafts are handed to the system app for confirmation and sending.
- **MCP extensions**: Expose local tools to external clients through a separately authorized MCP Bridge.

### Quick Start

[Download Asky 0.0.3](https://github.com/Niall-Young/Asky/releases/tag/v0.0.3) for macOS 26+ on Apple Silicon. Extract the ZIP and move `Asky.app` to Applications; Node.js and AgentRuntime are included. This test build is ad-hoc signed and has not been notarized by Apple, so first launch may trigger a system security prompt.

Requires macOS 26 or later, Xcode 26 (Swift 6.2 or later), Node.js 22 or later, and XcodeGen.

Run these commands from the repository root to build the development app:

```sh
(cd AgentRuntime && npm ci && npm run build)
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/Asky.app
```

### Usage

- Open search from the menu bar, enter an app name, file name, or web keyword, select with the arrow keys, and press Return to open.
- Type `1+1` to see a faint `= 2` suffix and a stacked card with the expression aligned left above the right-aligned result; press Return to copy the result. Long expressions occupy up to two lines with middle truncation; hover to see the full expression. Type `1美元`, `1 USD`, or `100人民币` to see a horizontal pair of cards showing the input currency and Chinese yuan (yuan inputs default to US dollars), with all other currencies listed underneath. Use `100 USD CNY` for a specific pair. Cards show flags, currencies, and amounts, without selection, hover, or copy actions. Rates use ECB daily references; offline use falls back to the cache or reports unavailable.
- `go` (Google search), `chat` (ChatGPT), `yt` (YouTube), `dy` (Douyin), `tb` (Taobao), `jd` (JD), `bl` (bilibili), `gh` (GitHub), and `>` (terminal) are fixed built-in commands that require no setup and cannot be added, edited, or deleted. View built-in commands with their brand logos and configure the terminal under Settings › Commands. Settings, the search field, and command results share 24 × 24 pt icons with 6 pt corners, transparent surrounding space, and no added background or border; `>` shows the selected terminal’s icon. Legacy web keyword settings no longer affect launcher routing; type `go query`, `chat question`, or a site shortcut such as `yt query` to use them.
- Type ASCII `>` followed by a space to enter terminal mode, for example `> pwd`; `>` alone or `>pwd` stays in ordinary search; Return opens the selected terminal and runs the command in the configured working directory. Choose an installed system Terminal, iTerm2, or Ghostty (1.3+) under Settings › Commands › Terminal › Terminal for Commands; the launcher and result show that app’s icon. Backspace on an empty field leaves terminal mode. First use may require Automation permission.
- Under Settings › General › File Search Scope, click “Choose Folder…” to add a search directory using the system folder picker.
- Press `Ctrl + Option + Command + V` to open clipboard history. Customize it under Settings › Trigger Shortcuts.
- Press `Ctrl + Option + Command + /` to open AI with a blank new conversation (without Shift); customize the combination or restore its default in Settings › Hotkeys › AI Conversation; an active reply is cancelled first. You can also open AI Conversation from the menu bar, or select and submit the AI entry in search.
- Press `⌘,` to open Settings while the search field or clipboard panel has focus. Settings uses native sidebar navigation with grouped configuration lists on the right and a resizable window. The app theme is under General › Appearance.
- Under Settings › About Asky, view the current version and click Check for Updates to read the latest GitHub release of `Niall-Young/Asky`. When it is newer than the running app, Install Update downloads the ZIP, verifies its `.sha256` checksum and code signature, replaces and deletes the old version after Asky quits, then reopens it. The app folder must be writable; a translocated app must first be moved to Applications.
- App language is under Settings › General › Language. It follows the preferred macOS language by default, with Simplified Chinese and English overrides; changes take effect on the next launch. Interface translations use native `.lproj` resources; macOS does not automatically translate custom app text. This setting does not control AI replies or user content.

### Configuration and Privacy

**The current version of Asky has no endpoint that uploads user data to the project author. Clipboard contents, conversations, files, and system data are not uploaded by the app to an author-operated server; AI requests go directly to your configured model service.** The author may receive issues, logs, or screenshots you submit voluntarily; redact them first.

See the [draft privacy policy (Chinese)](PRIVACY.md) for local storage, third-party processing, and current deletion limits. Publisher details, privacy contact information, and in-app notices must be completed before release; see the [privacy release review (Chinese)](docs/validation/2026-10-11-privacy-policy.md).

Before using AI, enter your provider's API endpoint, model name, and API key under Settings › Model Settings. Keys are stored in macOS Keychain; local data resides in `~/Library/Application Support/KulaHere/`.

Manage system permissions under Settings › System Permissions. Tools request authorization as needed. For Accessibility and Screen Recording, click Grant Access to open an independent native glass panel and the matching System Settings pane automatically. Drag its Asky.app card into the list, then turn on the switch. To grant access again, remove the old entry before dragging. The source card disappears when dragging starts, returns if the drag is cancelled or rejected, and stays hidden after an accepted drop. The panel keeps checking the running app’s access and closes when authorization is confirmed, also closing or hiding its permission pane; a different pane you have navigated to is preserved. A translocated app must first be moved to Applications and reopened. AI requests send submitted messages, attachments, and required tool results to the configured model service. Review that service's data handling before use.

### Project Structure and Documentation

| Path | Purpose |
| --- | --- |
| `App` | SwiftUI / AppKit interface, app assets, and native regression checks |
| `Packages/KulaCore` | Routing, storage, system tools, memory, scheduling, and authorization policies |
| `AgentRuntime` | TypeScript / Node.js Pi host communicating with the app over stdio JSONL |
| `MCPBridge` | SwiftPM MCP bridge executable |
| `project.yml` | XcodeGen project configuration |
| `docs` | Product, architecture, design, and validation documents |

Start with the [documentation index](docs/README.md). See the [V1 PRD](docs/PRD.md) for product scope and the [architecture outline](docs/framework.md) for module and process boundaries.

### Development and Verification

Run these commands from the repository root. Build the MCP Bridge before running core package tests:

```sh
(cd AgentRuntime && npm test)
(cd MCPBridge && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build)
(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)
```

After the Debug build in Quick Start, run native regression checks. Some interaction checks require system input event permissions:

```sh
python3 App/Tests/run-launcher-window-regression.py
python3 App/Tests/run-launcher-window-regression.py --command-icons
python3 App/Tests/run-launcher-terminal-regression.py
python3 App/Tests/run-launcher-calculation-regression.py
python3 App/Tests/run-launcher-window-regression.py --ai-routing
python3 App/Tests/run-launcher-window-regression.py --system-app-names
python3 App/Tests/run-launcher-window-regression.py --alias-routing
python3 App/Tests/run-clipboard-regression.py
python3 App/Tests/run-clipboard-regression.py --hover-delay
python3 App/Tests/run-clipboard-regression.py --settings-shortcut
python3 App/Tests/run-settings-regression.py
python3 App/Tests/run-application-language-regression.py -AppleLanguages "(en)"
python3 App/Tests/run-application-language-regression.py -AppleLanguages "(zh-Hans)"
python3 App/Tests/run-agent-reply-regression.py
```

For concurrent builds, the settings regression script accepts `ASKY_DERIVED_DATA` to select an isolated DerivedData directory (`KULAHERE_DERIVED_DATA` remains supported). It defaults to `build/DerivedData`.

Standalone checks for native input fields and hotkeys:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/LauncherSearchField.swift App/Sources/EditMenu.swift App/Tests/LauncherSearchFieldRegression.swift -o build/launcher-input-regression
build/launcher-input-regression
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/HotKey.swift App/Tests/HotKeyRegression.swift -o build/hotkey-regression
build/hotkey-regression
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/ConversationSearchField.swift App/Tests/ConversationSearchFieldRegression.swift -o build/conversation-search-regression
build/conversation-search-regression
```

Record only checks actually executed in `docs/validation/`. Track automated checks separately from acceptance testing of real system permissions, models, and interfaces.

### License

This project is licensed under the [MIT License](LICENSE), which permits use, modification, distribution, and commercial use, including closed-source derivatives. Copies or substantial portions of the software must retain the copyright and permission notices. The software is provided as is, without warranty.

Third-party dependencies and their bundled resources remain subject to their respective licenses; this project's MIT license does not replace those terms.

[中文](#中文) · [Back to top](#asky)
