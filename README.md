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

- **搜索**：应用、文件、Chrome 标签与书签，支持网页指令、终端、计算和汇率换算。
- **剪贴板**：文本、图片和文件历史，支持搜索、分类筛选、固定、预览与拖放，可切换卡片或列表视图。
- **AI 与记忆**：OpenAI 兼容接口、附件、对话历史、联网搜索，以及本地 Markdown 记忆。
- **系统与扩展**：按授权访问日历、提醒事项、备忘录和通讯录，支持情境提醒、可信 GitHub 插件和 MCP。官方插件：[飞书](https://github.com/Niall-Young/asky-plugin-lark)、[Orca](https://github.com/Niall-Young/asky-plugin-orca)。

### 安装与使用

[下载 Asky](https://github.com/Niall-Young/Asky/releases)（macOS 15+，Apple Silicon）。打开 DMG，将 `Asky.app` 拖入“应用程序”后启动。安装包已包含 Node.js 和 AgentRuntime；ZIP 用于应用内更新。自动更新默认开启，可在“设置 › 关于 Asky › 软件更新”关闭。

| 入口 | 用法 |
| --- | --- |
| 搜索 | 从菜单栏打开，输入关键词，方向键选择、回车打开 |
| 剪贴板 | `Ctrl + Shift + C` |
| AI 新对话 | `Ctrl + Shift + /` |
| 网页与终端 | `go 关键词`、`ds 问题`（填入后手动发送）、`yt 关键词`、`> pwd` |
| 设置 | 搜索或剪贴板获得焦点时按 `⌘,` |

网站指令仅提供内置预设，可在“设置 › 指令”中启停或修改触发词，不支持新增自定义网站。

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
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --website-commands
```

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

- **Search**: apps, files, Chrome tabs and bookmarks, web commands, terminal commands, calculations, and currency conversion.
- **Clipboard**: text, image, and file history with search, type filters, pinning, previews, and drag and drop, in card or list view.
- **AI and memory**: OpenAI-compatible providers, attachments, conversation history, web search, and local Markdown memory.
- **System and extensions**: authorized access to calendars, reminders, Notes, and contacts, plus contextual reminders, trusted GitHub plugins, and MCP. Official plugins: [Feishu](https://github.com/Niall-Young/asky-plugin-lark) and [Orca](https://github.com/Niall-Young/asky-plugin-orca).

### Install and Use

[Download Asky](https://github.com/Niall-Young/Asky/releases) (macOS 15+, Apple Silicon). Open the DMG, drag `Asky.app` into Applications, then launch it. Node.js and AgentRuntime are bundled; ZIP packages are for in-app updates. Automatic updates are enabled by default; disable them in Settings › About Asky › Software Update.

| Entry | Usage |
| --- | --- |
| Search | Open from the menu bar, type a keyword, select with arrow keys, press Return |
| Clipboard | `Ctrl + Shift + C` |
| New AI chat | `Ctrl + Shift + /` |
| Web and terminal | `go keyword`, `ds question` (prefills; send manually), `yt keyword`, `> pwd` |
| Settings | Press `⌘,` while search or clipboard has focus |

Website commands use built-in presets only. Enable or disable them and change their trigger tokens in Settings › Commands; adding custom websites is not supported.

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
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --website-commands
```

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
