<div align="center">

<img src="App/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" alt="KulaHere" width="128" height="128" />

# KulaHere

macOS 原生效率入口，连接本地搜索、剪贴板与按需 AI 助手。<br />
A native macOS launcher for local search, clipboard history, and an on-demand AI assistant.

[![macOS](https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&logoColor=white)](project.yml)
[![Swift](https://img.shields.io/badge/Swift-6.2%2B-F05138?logo=swift&logoColor=white)](Packages/KulaCore/Package.swift)
[![MCP](https://img.shields.io/badge/MCP-Bridge-6A1B9A)](docs/native-tools-and-mcp.md)

[中文](#中文) | [English](#english)

</div>

---

<a id="中文"></a>
## 中文

### 项目简介

KulaHere 使用 SwiftUI 与 AppKit 构建，提供菜单栏入口、聚焦搜索、剪贴板历史和 AI 对话。搜索与本地工具独立运行；AI 是按需启用的增强能力。

项目处于开发阶段，仓库包含原生 App、Swift 核心包、TypeScript Agent Runtime 和 MCP Bridge。系统权限、模型兼容性及完整交互流程仍需在实际环境中验收。

### 核心能力

- **聚焦搜索**：搜索应用、文件、Chrome 标签页与本地书签，读取应用自带的本地化名称（含系统应用的 `InfoPlist.loctable`），支持应用别名、网页关键词、计算和换算。
- **剪贴板历史**：独立面板浏览文本与图片，悬停 1.5 秒后显示完整预览，支持固定、删除和键盘选择；授予辅助功能权限后可直接粘贴。
- **AI 对话**：支持 OpenAI 兼容接口、对话历史、图片与文件附件，以及原生 Markdown 排版。Agent 辅助进程按需启动，空闲后退出。
- **系统工具**：通过 ToolService 统一处理系统读写与授权；集成日历、提醒事项、备忘录和通讯录，信息草稿交由系统 App 确认发送。
- **MCP 扩展**：通过独立授权的 MCP Bridge 向外部客户端提供本地工具。

### 快速开始

需要 macOS 26 或更新版本、Xcode 26（Swift 6.2 或更新版本）、Node.js 22 或更新版本，以及 XcodeGen。

在仓库根目录运行以下命令，构建开发版本：

```sh
(cd AgentRuntime && npm ci && npm run build)
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/KulaHere.app
```

### 使用方法

- 从菜单栏打开搜索，输入应用名、文件名或网页关键词，使用方向键选择、回车打开。
- 使用 `Ctrl + Option + Command + V` 打开剪贴板面板；可在“设置 › 触发快捷键”中修改快捷键。
- 使用 `Ctrl + Option + Command + ?` 直接打开 AI 并开启空白新对话（标准键盘为 `Ctrl + Option + Command + Shift + /`）；正在回复时先取消旧任务。也可从菜单栏打开“AI 对话”，或在搜索中选择 AI 条目后提交。
- 搜索框或剪贴板面板获得焦点时，按 `⌘,` 打开设置。设置窗口采用原生侧边栏导航，右侧显示分组配置列表，并支持调整窗口大小。

### 配置与隐私

使用 AI 前，在“设置 › 模型设置”中填写服务商的 API 地址、模型名和 API Key。Key 存储在 macOS 钥匙串中；本地数据位于 `~/Library/Application Support/KulaHere/`。

系统权限在“设置 › 系统权限”中管理，相关工具按需请求授权。AI 请求会将提交的消息、附件及所需工具结果发送到配置的模型服务。使用前请确认该服务的数据处理方式。

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
python3 App/Tests/run-launcher-window-regression.py --ai-routing
python3 App/Tests/run-launcher-window-regression.py --system-app-names
python3 App/Tests/run-launcher-window-regression.py --alias-routing
python3 App/Tests/run-clipboard-regression.py
python3 App/Tests/run-clipboard-regression.py --hover-delay
python3 App/Tests/run-clipboard-regression.py --settings-shortcut
python3 App/Tests/run-settings-regression.py
python3 App/Tests/run-agent-reply-regression.py
```

并行构建时，设置回归脚本支持用 `KULAHERE_DERIVED_DATA` 指定独立的 DerivedData 目录，默认使用 `build/DerivedData`。

原生输入框与快捷键的独立检查：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/LauncherSearchField.swift App/Tests/LauncherSearchFieldRegression.swift -o build/launcher-input-regression
build/launcher-input-regression
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/HotKey.swift App/Tests/HotKeyRegression.swift -o build/hotkey-regression
build/hotkey-regression
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/ConversationSearchField.swift App/Tests/ConversationSearchFieldRegression.swift -o build/conversation-search-regression
build/conversation-search-regression
```

检查结果按实际运行情况记录在 `docs/validation/`。自动化检查与真实系统权限、模型和界面验收分别记录。

[English](#english) · [返回顶部](#kulahere)

---

<a id="english"></a>
## English

### Overview

Built with SwiftUI and AppKit, KulaHere provides a menu bar entry point, focused search, clipboard history, and AI conversations. Search and local tools operate independently; AI is an optional enhancement invoked on demand.

The project is under active development. The repository includes the native app, Swift core packages, a TypeScript Agent Runtime, and an MCP Bridge. System permissions, model compatibility, and complete interaction flows still require acceptance testing in real environments.

### Features

- **Focused search**: Find apps, files, Chrome tabs, and local bookmarks, using each app’s localized names (including system app `InfoPlist.loctable` resources), with app aliases, web keywords, calculations, and unit conversions.
- **Clipboard history**: Browse text and images in a dedicated panel with full previews after hovering for 1.5 seconds, pinning, deletion, and keyboard selection. Direct paste requires Accessibility permission.
- **AI conversations**: Use OpenAI-compatible APIs with conversation history, image and file attachments, and native Markdown rendering. The agent helper starts on demand and exits when idle.
- **System tools**: ToolService manages system reads, writes, and authorization. Integrations cover Calendar, Reminders, Notes, and Contacts; message drafts are handed to the system app for confirmation and sending.
- **MCP extensions**: Expose local tools to external clients through a separately authorized MCP Bridge.

### Quick Start

Requires macOS 26 or later, Xcode 26 (Swift 6.2 or later), Node.js 22 or later, and XcodeGen.

Run these commands from the repository root to build the development app:

```sh
(cd AgentRuntime && npm ci && npm run build)
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/KulaHere.app
```

### Usage

- Open search from the menu bar, enter an app name, file name, or web keyword, select with the arrow keys, and press Return to open.
- Press `Ctrl + Option + Command + V` to open clipboard history. Customize it under Settings › Trigger Shortcuts.
- Press `Ctrl + Option + Command + ?` to open AI with a blank new conversation (`Ctrl + Option + Command + Shift + /` on a standard keyboard); an active reply is cancelled first. You can also open AI Conversation from the menu bar, or select and submit the AI entry in search.
- Press `⌘,` to open Settings while the search field or clipboard panel has focus. Settings uses native sidebar navigation with grouped configuration lists on the right and a resizable window.

### Configuration and Privacy

Before using AI, enter your provider's API endpoint, model name, and API key under Settings › Model Settings. Keys are stored in macOS Keychain; local data resides in `~/Library/Application Support/KulaHere/`.

Manage system permissions under Settings › System Permissions. Tools request authorization as needed. AI requests send submitted messages, attachments, and required tool results to the configured model service. Review that service's data handling before use.

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
python3 App/Tests/run-launcher-window-regression.py --ai-routing
python3 App/Tests/run-launcher-window-regression.py --system-app-names
python3 App/Tests/run-launcher-window-regression.py --alias-routing
python3 App/Tests/run-clipboard-regression.py
python3 App/Tests/run-clipboard-regression.py --hover-delay
python3 App/Tests/run-clipboard-regression.py --settings-shortcut
python3 App/Tests/run-settings-regression.py
python3 App/Tests/run-agent-reply-regression.py
```

For concurrent builds, the settings regression script accepts `KULAHERE_DERIVED_DATA` to select an isolated DerivedData directory. It defaults to `build/DerivedData`.

Standalone checks for native input fields and hotkeys:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/LauncherSearchField.swift App/Tests/LauncherSearchFieldRegression.swift -o build/launcher-input-regression
build/launcher-input-regression
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/HotKey.swift App/Tests/HotKeyRegression.swift -o build/hotkey-regression
build/hotkey-regression
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/ConversationSearchField.swift App/Tests/ConversationSearchFieldRegression.swift -o build/conversation-search-regression
build/conversation-search-regression
```

Record only checks actually executed in `docs/validation/`. Track automated checks separately from acceptance testing of real system permissions, models, and interfaces.

[中文](#中文) · [Back to top](#kulahere)
