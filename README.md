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

</div>

---

<a id="中文"></a>
## 中文

### 项目简介

Asky 是用 SwiftUI 与 AppKit 构建的 macOS 原生效率入口。搜索和剪贴板可独立使用，AI 助手按需启动。项目仍在开发中，完整系统权限与交互验收见[验证记录](docs/validation/)。

应用图标与设置中的品牌图使用黑色石墨质感，轮廓源文件见 [Mark.svg](App/Branding/Mark.svg)；菜单栏使用同轮廓的单色模板图。

### 核心能力

- **搜索**：应用、文件、Chrome 标签与书签，支持网页指令、终端、计算和汇率换算。
- **剪贴板**：保存文本、图片和文件历史，支持固定、复制与原生拖放。
- **AI 助手**：OpenAI 兼容接口、附件、对话历史和免额外 Key 的联网搜索。
- **个人记忆**：`MEMORY.md` 索引与按需读取的主题文件，支持明确保存、纠正、忘记及自动提炼与整理。
- **系统与扩展**：按授权访问日历、提醒事项、备忘录与通讯录，支持情境提醒、可信 GitHub 插件和 MCP。

### 快速开始

[下载 Asky](https://github.com/Niall-Young/Asky/releases)（macOS 15+，Apple Silicon）。打开 DMG，将 `Asky.app` 拖入“应用程序”后启动；安装包已包含 Node.js 和 AgentRuntime。ZIP 用于应用内更新。

首次使用见[使用教程](docs/user-guide.md)。

### 使用方法

| 入口 | 用法 |
| --- | --- |
| 搜索 | 从菜单栏打开，输入关键词，方向键选择、回车打开 |
| 剪贴板 | `Ctrl + Shift + C` |
| AI 新对话 | `Ctrl + Shift + /` |
| 网页与终端 | `go 关键词`、`yt 关键词`、`> pwd` |
| 设置 | 搜索或剪贴板获得焦点时按 `⌘,` |

快捷键可在设置中修改。Chrome 搜索与系统工具需要相应授权。

### 配置与隐私

在“设置 › 模型设置”填写 API 地址、模型名和 Key；Key 保存在 macOS 钥匙串，本地数据位于 `~/Library/Application Support/KulaHere/`。

应用没有向作者上传用户数据的接口。AI 消息、附件和所需工具结果发送至你配置的模型服务；联网搜索词发送至 Bing。记忆保存在本机 Markdown 文件中；启用后，索引、按需读取的主题和自动提炼、整理所需内容也会发送至模型服务。来源开关与系统权限在设置中管理。详见[隐私政策草案](PRIVACY.md)。

### 项目结构与文档

`App/` 是原生界面，`Packages/KulaCore/` 是核心能力与 ToolService，`AgentRuntime/` 是 TypeScript AI 宿主，`MCPBridge/` 是外部工具桥接。

[文档索引](docs/README.md) · [产品需求](docs/PRD.md) · [架构](docs/framework.md) · [插件指南](docs/plugins.md)

### 开发与验证

需要 Xcode 26 / Swift 6.2+、Node.js 22+ 和 XcodeGen。从仓库根目录构建：

```sh
python3 scripts/setup-local-signing.py
(cd AgentRuntime && npm ci && npm run build)
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/Asky.app
```

常用检查（先构建 MCP Bridge，再测核心包）：

```sh
(cd AgentRuntime && npm test)
(cd MCPBridge && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build)
(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)
```

原生回归、通知预览与 `scripts/package-release.py` 打包流程见[开发与发布指南](docs/development.md)。打包前提交源码并保持工作区干净；使用固定的 `Asky Local Signing` 证书，生成 DMG、更新 ZIP 与校验文件。检查结果写入 `docs/validation/`。

### 开源协议

[MIT](LICENSE)。第三方依赖遵循各自的许可证。

[English](#english) · [返回顶部](#asky)

---

<a id="english"></a>
## English

### Overview

Asky is a native macOS launcher built with SwiftUI and AppKit. Search and clipboard history work independently; the AI assistant starts on demand. The project is in development; see [validation records](docs/validation/) for system permission and interaction acceptance status.

The app icon and branding in Settings use a black graphite finish based on [Mark.svg](App/Branding/Mark.svg). The menu bar uses the same silhouette as a monochrome template.

### Features

- **Search**: apps, files, Chrome tabs and bookmarks, web commands, terminal commands, calculations, and currency conversion.
- **Clipboard**: text, image, and file history with pinning, copying, and native drag and drop.
- **AI assistant**: OpenAI-compatible providers, attachments, conversation history, and web search without an extra API key.
- **Personal memory**: a `MEMORY.md` index and topic files read on demand, with explicit saves, corrections, forgetting, automatic extraction, and consolidation.
- **System and extensions**: authorized access to calendars, reminders, Notes, and contacts, plus contextual suggestions, trusted GitHub plugins, and MCP.

### Quick Start

[Download Asky](https://github.com/Niall-Young/Asky/releases) (macOS 15+, Apple Silicon). Open the DMG, drag `Asky.app` into Applications, then launch it. Node.js and AgentRuntime are bundled; ZIP packages are for in-app updates.

Start with the [user guide (Chinese)](docs/user-guide.md).

### Usage

| Entry | Usage |
| --- | --- |
| Search | Open from the menu bar, type a keyword, select with arrow keys, press Return |
| Clipboard | `Ctrl + Shift + C` |
| New AI chat | `Ctrl + Shift + /` |
| Web and terminal | `go keyword`, `yt keyword`, `> pwd` |
| Settings | Press `⌘,` while search or clipboard has focus |

Shortcuts are configurable in Settings. Chrome search and system tools require the relevant permissions.

### Configuration and Privacy

Enter the API URL, model name, and key in Settings › Model Settings. Keys stay in the macOS keychain; local data lives in `~/Library/Application Support/KulaHere/`.

The app has no interface for uploading user data to the author. AI messages, attachments, and required tool results go to your configured model provider; web search queries go to Bing. Memory is stored in local Markdown files; when enabled, the index, requested topics, and content needed for extraction and consolidation also go to the model provider. Manage data sources and system permissions in Settings. See the [draft privacy policy](PRIVACY.md).

### Project Structure and Docs

`App/` contains the native UI, `Packages/KulaCore/` the core capabilities and ToolService, `AgentRuntime/` the TypeScript AI host, and `MCPBridge/` the external tool bridge.

[Docs index](docs/README.md) · [Product requirements](docs/PRD.md) · [Architecture](docs/framework.md) · [Plugin guide](docs/plugins.md)

### Development and Verification

Requires Xcode 26 / Swift 6.2+, Node.js 22+, and XcodeGen. Build from the repository root:

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
```

See the [development and release guide](docs/development.md) for native regressions, notification previews, and the `scripts/package-release.py` workflow. Commit source changes and keep the working tree clean before packaging. Use the persistent `Asky Local Signing` certificate to produce a DMG, updater ZIP, and checksums. Record checks in `docs/validation/`.

### License

[MIT](LICENSE). Third-party dependencies retain their own licenses.

[中文](#中文) · [Back to top](#asky)
