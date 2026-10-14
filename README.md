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
- **剪贴板**：保存文本、图片和文件历史，支持固定、复制与原生拖放。文件搜索排除目录和剪贴板排除应用在设置中逐项添加、编辑和删除；添加或编辑时使用系统选择面板，目录自动取目录名，应用自动取 Bundle ID。
- **AI 助手**：OpenAI 兼容接口、附件、对话历史和免额外 Key 的联网搜索。
- **个人记忆**：`MEMORY.md` 索引与按需读取的主题文件，支持明确保存、纠正、忘记及自动提炼与整理。
- **系统与扩展**：按授权访问日历、提醒事项、备忘录与通讯录，支持情境提醒、可信 GitHub 插件和 MCP。

### 与同类工具对比

| | Asky | Spotlight | Raycast | Alfred |
| --- | --- | --- | --- | --- |
| 开源 | ✅ MIT | ❌ | ❌（扩展开源） | ❌ |
| 价格 | 免费 | 系统自带 | 免费，AI 需付费方案 | 免费，Powerpack 付费 |
| 剪贴板历史 | ✅ 文本、图片、文件 | ✅ macOS 26 起，默认关闭 | ✅ | Powerpack |
| AI 助手 | 自带 API Key，OpenAI 兼容，预设 DeepSeek、Kimi、Qwen 等 | Apple Intelligence | Raycast AI（付费方案） | 需第三方 Workflow |
| 本地 Markdown 记忆 | ✅ | ❌ | ❌ | ❌ |
| MCP | ✅ | ❌ | ✅ | ❌ |

对比基于 2026 年 10 月的公开信息，各产品功能以官方说明为准。

### 快速开始

[下载 Asky](https://github.com/Niall-Young/Asky/releases)（macOS 15+，Apple Silicon）。打开 DMG，将 `Asky.app` 拖入“应用程序”后启动；安装包已包含 Node.js 和 AgentRuntime。ZIP 用于应用内更新。

安装到“应用程序”后，自动更新默认开启：后台下载并校验新版本，在你不使用 Asky 时完成更新；可在“设置 › 关于 Asky › 软件更新”关闭。

首次使用见[使用教程](docs/user-guide.md)。

### 使用方法

| 入口 | 用法 |
| --- | --- |
| 搜索 | 从菜单栏打开，输入关键词，方向键选择、回车打开 |
| 剪贴板 | `Ctrl + Shift + C` |
| AI 新对话 | `Ctrl + Shift + /` |
| 网页与终端 | `go 关键词`、`yt 关键词`、`> pwd` |
| 设置 | 搜索或剪贴板获得焦点时按 `⌘,` |

在“设置 › 触发快捷键”的统一列表中修改快捷键或逐项恢复默认，包括启动器、剪贴板、AI 对话，以及启动器内的“在访达中显示”（`⌘F`）和“复制文件路径”（`⌥⌘C`）。后两项需要选中文件或应用。Chrome 搜索与系统工具需要相应授权。
“设置 › 通用 › 启动”中的“显示菜单栏图标”开关立即生效并保存，默认开启；隐藏图标后仍可通过快捷键唤起应用。

### 配置与隐私

在“设置 › 智能配置”选择 DeepSeek、MiniMax、GLM、Kimi、Qwen 或 OpenAI，预设自动填写 API 地址并提供模型选项，只需输入 API Key。选择“完全自定义”可手动填写 OpenAI 兼容地址和模型名。切换 API 地址后需填写对应的新 Key。Key 保存在 macOS 钥匙串，本地数据位于 `~/Library/Application Support/KulaHere/`。先保存再检查配置；检查失败时显示 HTTP 状态与服务商原因。余额不足、认证失败或网络错误不代表模型不支持对应能力。

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

Debug 构建在 `project.yml` 中关闭 `ENABLE_DEBUG_DYLIB`，避免无 Team ID 的本地签名在 Hardened Runtime 下加载独立 Debug 动态库失败。普通运行与调试可用，但 App target 的 SwiftUI Previews 不可用；更改配置后重新执行 `xcodegen generate` 和上述构建命令。

常用检查（先构建 MCP Bridge，再测核心包）：

```sh
(cd AgentRuntime && npm test)
(cd MCPBridge && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build)
(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)
```

服务商预设回归：先执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/ModelProviderPreset.swift App/Tests/ModelProviderRegression.swift -o build/model-provider-regression`，再运行 `build/model-provider-regression`。

聊天图片剪贴板回归：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --chat-images`（先完成 Debug 构建）。

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
- **Clipboard**: text, image, and file history with pinning, copying, and native drag and drop. Settings provide individual add, edit, and delete controls for excluded search directories and clipboard apps. Adding or editing opens a system picker; folder names and app bundle IDs are extracted automatically.
- **AI assistant**: OpenAI-compatible providers, attachments, conversation history, and web search without an extra API key.
- **Personal memory**: a `MEMORY.md` index and topic files read on demand, with explicit saves, corrections, forgetting, automatic extraction, and consolidation.
- **System and extensions**: authorized access to calendars, reminders, Notes, and contacts, plus contextual suggestions, trusted GitHub plugins, and MCP.

### Comparison

| | Asky | Spotlight | Raycast | Alfred |
| --- | --- | --- | --- | --- |
| Open source | ✅ MIT | ❌ | ❌ (extensions are open) | ❌ |
| Price | Free | Built into macOS | Free; AI requires a paid plan | Free; Powerpack is paid |
| Clipboard history | ✅ Text, images, files | ✅ Since macOS 26, off by default | ✅ | Powerpack |
| AI assistant | Your own API key, OpenAI-compatible, presets for DeepSeek, Kimi, Qwen, and more | Apple Intelligence | Raycast AI (paid plan) | Third-party workflows |
| Local Markdown memory | ✅ | ❌ | ❌ | ❌ |
| MCP | ✅ | ❌ | ✅ | ❌ |

Based on public information as of October 2026; refer to each product's official documentation.

### Quick Start

[Download Asky](https://github.com/Niall-Young/Asky/releases) (macOS 15+, Apple Silicon). Open the DMG, drag `Asky.app` into Applications, then launch it. Node.js and AgentRuntime are bundled; ZIP packages are for in-app updates.

When installed in Applications, automatic updates are enabled by default. Asky downloads and verifies new versions in the background, then installs them when you are not using the app. Disable this in Settings › About Asky › Software Update.

Start with the [user guide (Chinese)](docs/user-guide.md).

### Usage

| Entry | Usage |
| --- | --- |
| Search | Open from the menu bar, type a keyword, select with arrow keys, press Return |
| Clipboard | `Ctrl + Shift + C` |
| New AI chat | `Ctrl + Shift + /` |
| Web and terminal | `go keyword`, `yt keyword`, `> pwd` |
| Settings | Press `⌘,` while search or clipboard has focus |

Settings › Keyboard Shortcuts provides one list with editable shortcuts and per-row resets for the launcher, clipboard, AI chat, and the launcher actions Reveal in Finder (`⌘F`) and Copy file path (`⌥⌘C`). The last two require a selected file or app. Chrome search and system tools require the relevant permissions.
The “Show menu bar icon” switch in Settings › General › Startup takes effect immediately and persists, with the icon shown by default. Keyboard shortcuts remain available when the icon is hidden.

### Configuration and Privacy

Choose DeepSeek, MiniMax, GLM, Kimi, Qwen, or OpenAI in Settings › Model Settings. Presets fill in the API URL and offer model choices; only your API key is required. Choose Fully custom to enter an OpenAI-compatible URL and model ID manually. Changing the API URL requires the corresponding new key. Keys stay in the macOS keychain; local data lives in `~/Library/Application Support/KulaHere/`. Save before checking the configuration. Failed checks show the HTTP status and provider reason; balance, authentication, and network errors do not establish that a model lacks a capability.

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

Debug builds disable `ENABLE_DEBUG_DYLIB` in `project.yml` because the local signing identity has no Team ID and Hardened Runtime rejects the separate debug library. Normal running and debugging remain available, but SwiftUI Previews for the app target are unavailable. After changing the configuration, rerun `xcodegen generate` and the build command above.

Common checks (build MCP Bridge before testing the core package):

```sh
(cd AgentRuntime && npm test)
(cd MCPBridge && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build)
(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)
```

Provider preset regression: compile with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/ModelProviderPreset.swift App/Tests/ModelProviderRegression.swift -o build/model-provider-regression`, then run `build/model-provider-regression`.

Chat-image clipboard regression: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --chat-images` (build Debug first).

See the [development and release guide](docs/development.md) for native regressions, notification previews, and the `scripts/package-release.py` workflow. Commit source changes and keep the working tree clean before packaging. Use the persistent `Asky Local Signing` certificate to produce a DMG, updater ZIP, and checksums. Record checks in `docs/validation/`.

### License

[MIT](LICENSE). Third-party dependencies retain their own licenses.

[中文](#中文) · [Back to top](#asky)
