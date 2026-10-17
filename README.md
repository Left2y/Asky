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

### 项目简介

Asky 是用 SwiftUI 与 AppKit 构建的 macOS 原生效率入口。搜索和剪贴板可独立使用，AI 助手按需启动。项目仍在开发中，完整系统权限与交互验收见[验证记录](docs/validation/)。

应用内 dialog / alert 统一采用 macOS 原生 `NSAlert`：有所属窗口时使用 sheet，无所属窗口时使用独立 alert；外观与按钮布局由系统管理。操作确认用一段自然语言说明目标与变更，不提供详情展开项。

功能图标统一使用本地打包的 MingCute 矢量模板，保留品牌标识、真实应用图标，以及启动器“打开链接”和“搜索书签”的原有彩色图标。AI 工具调用图标槽统一为 16×16 pt，记忆调用使用 brain 图标，插件工具调用统一使用 tool 图标，设置页的官方与已安装插件保留对应应用 Logo（优先使用插件声明的图标），失败使用圆形感叹号；点击工具调用文字及其后方箭头展开/收起错误详情，详情高度与透明度平滑过渡，箭头同步旋转；开启系统“减少动态效果”时立即切换。映射与固定上游版本见 [图标清单](scripts/mingcute-icons.json)；更新资源使用 `python3 scripts/import-mingcute-icons.py /path/to/mingcute-icons`，传入清单记录版本的上游 checkout。

应用图标与设置中的品牌图采用浅蓝磨砂小伙伴：无触角、歪头微笑、深蓝底与放大裁切。正式主图见 [Logo.png](App/Branding/Logo.png)，独立图标包见 [Asky.icns](App/Branding/Asky.icns)，菜单栏使用其简化单色轮廓 [Mark.svg](App/Branding/Mark.svg)。

### 核心能力

- **搜索**：应用、文件、Chrome 标签与书签，支持网页指令、终端、计算和汇率换算。内置网页指令包括 `go`、`chat`、`ds`（DeepSeek）、`yt`、`dy`、`tb`、`jd`、`bl`、`gh`、`bd`（百度）、`hb`（花瓣）、`zh`（知乎）、`xhs`（小红书）、`wb`（微博），使用随应用打包的品牌 Logo。“设置 › 指令”顶部支持按指令缩写或名称即时搜索，清除搜索可恢复完整列表。默认全部开启，可用左侧复选框逐项关闭；关闭后不再匹配指令或显示对应搜索候选，重启后保留。
- **剪贴板**：保存文本、图片和文件历史，支持固定、复制与原生拖放。搜索框旁的筛选按钮默认选择“全部”，可切换图片、视频、文本、文件，并与关键词搜索组合使用。文档和视频复制时附带的图标或缩略图不会替代原文件记录。列表式的文档预览居中显示系统文件图标及下方文件名，左侧使用紧凑图标；纯文本使用带中性圆角背景的剪贴板图标。单个本地视频文件支持在列表详情和卡片悬停区域中使用原生播放器预览，点击播放；原文件须仍可读取，格式支持取决于系统。默认使用卡片式，可在“设置 › 通用 › 剪贴板 › 显示方式”中切换为左侧历史列表、右侧内容预览的列表式；历史列表项沿用搜索结果的行高、图标尺寸、文字层级及悬停与选中背景，采用 38 pt 单行布局与 24 pt 图标，不显示时间副标题，切换保留搜索与选中项。列表式支持点击记录或按回车复制当前选中内容，显示“已复制”提示并保持窗口打开；方向键切换预览。列表式窗口为 720 × 560 pt，左右区域保持原有比例（左侧 272 pt）。右侧预览下方的信息区逐行显示来源、类型、像素尺寸、大小与复制时间；不适用或无法读取的值显示为“—”。文件搜索排除目录和剪贴板排除应用在设置中逐项添加、编辑和删除；添加或编辑时使用系统选择面板，目录自动取目录名，应用自动取 Bundle ID。
- **AI 助手**：OpenAI 兼容接口、附件、对话历史和免额外 Key 的联网搜索。每轮工作时长显示在回复上方，有工具调用时可点击箭头查看详情，完成后默认收起；不显示调用次数，没有工具调用时只显示时长。回复左下方为复制按钮和完成时间：不足 1 分钟显示“刚刚”，1 小时内显示分钟前，24 小时内显示小时前，3 天内显示天前，之后显示精确到秒的日期时间；悬停可查看完整时间。向上浏览对话时，输入框上方 8pt 显示圆形玻璃向下按钮，点击回到底部。
- **个人记忆**：`MEMORY.md` 索引与按需读取的主题文件，支持明确保存、纠正、忘记及自动提炼与整理。
- **系统与扩展**：按授权访问日历、提醒事项、备忘录与通讯录，支持情境提醒、可信 GitHub 插件和 MCP。官方插件 [飞书](https://github.com/Niall-Young/asky-plugin-lark) 与 [Orca](https://github.com/Niall-Young/asky-plugin-orca) 在独立仓库发布。

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

首次使用见[使用教程](https://asky.niallyoung2002.workers.dev/docs)。

### 使用方法

| 入口 | 用法 |
| --- | --- |
| 搜索 | 从菜单栏打开，输入关键词，方向键选择、回车打开 |
| 剪贴板 | `Ctrl + Shift + C` |
| AI 新对话 | `Ctrl + Shift + /` |
| 网页与终端 | `go 关键词`、`ds 问题`（填入后手动发送）、`yt 关键词`、`> pwd` |
| 设置 | 搜索或剪贴板获得焦点时按 `⌘,` |

启动器总宽为 720 pt，初始顶部位于屏幕可用高度的 18%；结果列表最高 380 pt（含分组标题），并按屏幕底部空间收缩。搜索采用紧凑单行结果：左侧显示 24 pt 图标与名称，右侧显示应用、文件格式或来源类型，不显示路径；文件路径仍可用快捷键复制。

在默认搜索中输入 `asky`（不区分大小写），首项为“关闭 Asky”，显示白底红色 Logo，应用结果仍保留。点击或按回车后弹出原生确认 Alert；取消继续使用，确认后退出应用。

结果底部提供悬浮操作区：左侧按选中项展示常用操作，无可用动作时隐藏；右侧「更多 ⌘K」只在有附加动作时显示。应用和文件可在更多中选择「在访达中显示」「复制路径」，链接和标签页可复制链接。`⌘K` 打开/关闭更多菜单，`↑` / `↓` 选择菜单动作、`Return` 执行，`Escape` 关闭菜单；关闭后保留搜索词与结果选择，方向键继续选择结果。列表在悬浮控件下方渐隐，滚动末尾保留操作区空间。

在“设置 › 触发快捷键”的统一列表中修改快捷键或逐项恢复默认，包括启动器、剪贴板、AI 对话，以及启动器内的“在访达中显示”（`⌘F`）和“复制文件路径”（`⌥⌘C`）。后两项需要选中文件或应用。Chrome 搜索与系统工具需要相应授权。
“设置 › 通用 › 启动”中的“显示菜单栏图标”开关立即生效并保存，默认开启；隐藏图标后仍可通过快捷键唤起应用。“在 Dock 栏显示”默认关闭，打开设置也不会显示 Dock 图标；开启后即使关闭所有窗口也保留 Dock 图标，点击图标可重新打开入口，主动退出应用后结束常驻。

主动提醒使用 Asky 自绘的右上角提醒卡片，显示当前应用图标，默认无声且不抢焦点；无需系统通知权限，不进入通知中心。Asky 退出后不弹出提醒，重新启动或唤醒时校验计划。开启后台 AI、短信读取并授权后，可从短信/iMessage 中提取明确预约，在卡片中点击“创建日程”，在 Asky 的分组圆角弹窗中修改标题、起止时间、地点、目标日历和备注，点击“创建”后直接保存，无需打开日历应用；截止事项仍作为提醒建议。

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

提醒卡片展开回归：`build/DerivedData/Build/Products/Debug/Asky.app/Contents/MacOS/Asky --test-banner --test-banner-reflow`（先完成 Debug 构建），自动折叠后再次展开并保持显示，检查相邻卡片的阴影是否遮挡内容

常用检查（先构建 MCP Bridge，再测核心包）：

```sh
(cd AgentRuntime && npm test)
(cd MCPBridge && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build)
(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)
```

请求确认全量预览：Debug 构建后运行 `open -n build/DerivedData/Build/Products/Debug/Asky.app --args --test-confirmation-matrix`；每个场景依次选择“确认执行”和“不执行”，只测试界面与返回结果，不执行真实工具。

服务商预设回归：先执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/ModelProviderPreset.swift App/Tests/ModelProviderRegression.swift -o build/model-provider-regression`，再运行 `build/model-provider-regression`。

悬浮操作区回归：完成 Debug 构建后执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --action-bar`，检查菜单键盘路由、焦点、复制路径、结果选择恢复与深浅色实际窗口。

退出搜索回归：完成 Debug 构建后，运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-quit-asky-regression.py`，检查排序、精确匹配、取消、确认和浅色/深色窗口。

Dock 常驻回归：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --dock-only`（先完成 Debug 构建）。

聊天图片剪贴板回归：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --chat-images`（先完成 Debug 构建）。

剪贴板布局回归：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts`（先完成 Debug 构建），检查布局切换、选中项保留、搜索、固定与复制，并生成实际窗口截图。

剪贴板筛选回归：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --filters`（先完成 Debug 构建），检查类型筛选、较早历史、搜索组合、菜单定位与重新打开后的默认项。

视频预览回归：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --video-preview`（先完成 Debug 构建，并在 PATH 中提供 FFmpeg），生成 H.264 MP4，检查列表与悬停预览、切换、关闭及原文件复制，并生成窗口截图。追加 `--portrait-video` 使用竖版视频；横竖版均检查播放控件出现后预览尺寸保持稳定。

复制提示条回归：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --toast-surfaces`（先完成 Debug 构建），检查深浅色圆角表面并生成截图。

日程配置回归：Debug 构建后执行 `python3 App/Tests/run-calendar-editor-regression.py`；加 `--preview` 查看无真实写入的示例，另加 `--preview-error` 检查冲突后修改重试。

对话、启动器和设置回归可通过 `ASKY_DERIVED_DATA=/path/to/DerivedData` 使用对应的 Debug 构建产物，便于并行验证。

原生回归、通知预览与 `scripts/package-release.py` 打包流程见[开发与发布指南](docs/development.md)。打包前提交源码并保持工作区干净；使用固定的 `Asky Local Signing` 证书，生成 DMG、更新 ZIP 与校验文件。检查结果写入 `docs/validation/`。

### 开源协议

[MIT](LICENSE)。第三方依赖遵循各自的许可证。

[English](#english) · [返回顶部](#asky)

---

<a id="english"></a>
## English

### Overview

Asky is a native macOS launcher built with SwiftUI and AppKit. Search and clipboard history work independently; the AI assistant starts on demand. The project is in development; see [validation records](docs/validation/) for system permission and interaction acceptance status.

In-app dialogs and alerts use native macOS `NSAlert`: a sheet when an owning window is available, or a standalone alert otherwise. The system manages appearance and button layout. Action confirmations describe the target and changes in one paragraph, without an expandable details section.

Functional icons use bundled MingCute vector templates; brand marks, real application icons, and the launcher’s original colored Open Link and Search Bookmarks icons retain their original artwork. AI tool-call icon slots are 16×16 pt. Memory calls use a brain icon, plugin tool calls share the tool icon, and failures use a circular exclamation mark. Official and installed plugins in Settings retain the corresponding app logo, preferring plugin-provided artwork when available. Click a failed call’s label and trailing arrow to expand or collapse its error details, with animated height, opacity, and arrow rotation. When Reduce Motion is enabled, the state changes immediately. See the [icon manifest](scripts/mingcute-icons.json) for mappings and the pinned upstream revision. Refresh assets with `python3 scripts/import-mingcute-icons.py /path/to/mingcute-icons`, using an upstream checkout at the recorded revision.

The app icon and branding in Settings feature a pale-blue frosted companion with a smooth hornless silhouette, tilted smile, dark navy background, and enlarged crop. The production master is [Logo.png](App/Branding/Logo.png), with a standalone [Asky.icns](App/Branding/Asky.icns) export; the menu bar uses its simplified monochrome silhouette in [Mark.svg](App/Branding/Mark.svg).

### Features

- **Search**: apps, files, Chrome tabs and bookmarks, web commands, terminal commands, calculations, and currency conversion. Built-in web commands include `go`, `chat`, `ds` (DeepSeek), `yt`, `dy`, `tb`, `jd`, `bl`, `gh`, `bd` (Baidu), `hb` (Huaban), `zh` (Zhihu), `xhs` (Xiaohongshu), and `wb` (Weibo), with bundled brand logos. Search by command keyword or name at the top of Settings › Commands; clear the search to restore the full list. All are enabled by default. Use the checkboxes on the left to disable individual commands; disabled commands no longer match input or appear as search suggestions, and the setting persists across restarts.
- **Clipboard**: text, image, and file history with pinning, copying, and native drag and drop. Icons or thumbnails accompanying copied documents and videos do not replace the original file records. List details center system file icons with filenames underneath for documents, with compact icons on the left; plain text uses a clipboard icon on a rounded neutral background. Single local video files use the native video player in list details and card hover previews; click to play. The original file must remain readable, and format support depends on macOS. Cards are the default; Settings › General › Clipboard › Display Style switches to a history list with a content preview on the right, preserving the query and selection. History rows share search results’ row height, icon size, typography, and hover and selection backgrounds; rows use a 38 pt single-line layout with 24 pt icons and no time subtitle. In list mode, clicking a row or pressing Return copies the selected content, shows a copy toast, and keeps the window open; arrow keys switch the preview. The list window measures 720 × 560 pt and preserves the original pane proportions (272 pt on the left). Information below the preview lists source, type, pixel dimensions, size, and copy time in aligned rows; unavailable or inapplicable values show “—”. Settings provide individual add, edit, and delete controls for excluded search directories and clipboard apps. Adding or editing opens a system picker; folder names and app bundle IDs are extracted automatically. The filter button beside search defaults to All and offers Images, Videos, Text, and Files; type filters combine with the search query.
- **AI assistant**: OpenAI-compatible providers, attachments, conversation history, and web search without an extra API key. Each turn shows its work duration above the reply; when tools were called, click the arrow for details. Calls collapse when the task finishes. Call counts are hidden; turns without tool calls show only the duration. Copy and completion time appear at the lower left: just now under a minute, minutes under an hour, hours under 24 hours, days under three days, then a date and time including seconds. Hover for the exact timestamp. While browsing earlier messages, a circular glass down-arrow button appears 8pt above the composer; click it to return to the bottom.
- **Personal memory**: a `MEMORY.md` index and topic files read on demand, with explicit saves, corrections, forgetting, automatic extraction, and consolidation.
- **System and extensions**: authorized access to calendars, reminders, Notes, and contacts, plus contextual suggestions, trusted GitHub plugins, and MCP. Official plugins [Feishu](https://github.com/Niall-Young/asky-plugin-lark) and [Orca](https://github.com/Niall-Young/asky-plugin-orca) are published in separate repositories.

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

Start with the [user guide (Chinese)](https://asky.niallyoung2002.workers.dev/docs).

### Usage

| Entry | Usage |
| --- | --- |
| Search | Open from the menu bar, type a keyword, select with arrow keys, press Return |
| Clipboard | `Ctrl + Shift + C` |
| New AI chat | `Ctrl + Shift + /` |
| Web and terminal | `go keyword`, `ds question` (prefills; send manually), `yt keyword`, `> pwd` |
| Settings | Press `⌘,` while search or clipboard has focus |

The launcher is 720 pt wide and opens 18% down the screen’s usable area. The result list is capped at 380 pt including section headers, shrinking as needed to fit above the screen’s bottom edge. Search uses compact single-line results with a 24 pt icon and name on the left and the application, file format, or source type on the right. Paths are hidden from rows and remain available through the Copy file path shortcut.

Type `asky` (case-insensitive) in the default search to see “Quit Asky” first with a red logo on white, followed by app results. Clicking it or pressing Return opens a native confirmation alert; cancel to keep using Asky, or confirm to quit.

A floating action area overlays the bottom of the results. The left side shows the selected item's primary action and hides when none is available; “More ⌘K” appears on the right only when secondary actions exist. Apps and files offer Reveal in Finder and Copy path; links and tabs offer Copy link. Press `⌘K` to toggle More, `↑` / `↓` to choose an action, `Return` to execute, or `Escape` to dismiss. Closing the menu preserves the query and result selection, and arrow keys resume navigating results. Rows fade beneath the floating controls, with extra clearance at the end of the scrollable content.

Settings › Keyboard Shortcuts provides one list with editable shortcuts and per-row resets for the launcher, clipboard, AI chat, and the launcher actions Reveal in Finder (`⌘F`) and Copy file path (`⌥⌘C`). The last two require a selected file or app. Chrome search and system tools require the relevant permissions.
The “Show menu bar icon” switch in Settings › General › Startup takes effect immediately and persists, with the icon shown by default. Keyboard shortcuts remain available when the icon is hidden. “Show in Dock” is off by default, and opening Settings does not show the Dock icon. When enabled, the Dock icon stays visible after all windows close; click it to reopen the launcher. Quit the app to end its running session.

Proactive reminders use Asky’s own top-right cards with the current app icon. They are silent and do not take focus, require no system notification permission, and do not enter Notification Center. No reminders appear after Asky quits; plans are revalidated on launch or wake. With background AI, message reading, and the required access enabled, explicit appointments in SMS/iMessage can offer a Create event action. Edit the title, start/end times, location, destination calendar, and notes in Asky’s compact dialog, then click Create to save without opening Calendar; deadlines remain reminder suggestions.

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

Reminder expansion check: after building Debug, run `build/DerivedData/Build/Products/Debug/Asky.app/Contents/MacOS/Asky --test-banner --test-banner-reflow`. The preview folds, expands again, and stays visible so you can inspect whether shadows overlap neighbouring card content.

Common checks (build MCP Bridge before testing the core package):

```sh
(cd AgentRuntime && npm test)
(cd MCPBridge && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build)
(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)
```

Full confirmation preview: after building Debug, run `open -n build/DerivedData/Build/Products/Debug/Asky.app --args --test-confirmation-matrix`. Choose Confirm, then Decline, for each scenario; this checks UI and response handling without executing real tools.

Provider preset regression: compile with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/ModelProviderPreset.swift App/Tests/ModelProviderRegression.swift -o build/model-provider-regression`, then run `build/model-provider-regression`.

Floating action area regression: after the Debug build, run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --action-bar` to check menu keyboard routing, focus, path copying, restored result navigation, and actual light/dark windows.

Quit search regression: after building Debug, run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-quit-asky-regression.py` to check ranking, exact matching, cancellation, confirmation, and light/dark windows.

Dock visibility regression: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --dock-only` (build Debug first).

Chat-image clipboard regression: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --chat-images` (build Debug first).

Clipboard layout regression: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts` (build Debug first) checks layout switching, selection retention, search, pinning, and copying, and captures actual window snapshots.

Clipboard filter regression: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --filters` (after the Debug build) checks categories, older history, combined search, menu placement, and the default selection on reopening.

Video preview regression: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --video-preview` (build Debug first; FFmpeg must be on PATH) generates an H.264 MP4 and checks list and hover previews, selection switching, dismissal, and original-file copying, with window snapshots. Add `--portrait-video` to use a portrait fixture; both orientations check that revealing playback controls preserves the preview size.

Copy-toast regression: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --toast-surfaces` (build Debug first) checks rounded surfaces in light and dark appearances and captures snapshots.

Calendar editor regression: after the Debug build, run `python3 App/Tests/run-calendar-editor-regression.py`; add `--preview` for a sample without calendar writes, and `--preview-error` to check editing and retrying after a conflict.

Agent reply, launcher, and settings regressions accept `ASKY_DERIVED_DATA=/path/to/DerivedData` to use the matching Debug build products during parallel validation.

See the [development and release guide](docs/development.md) for native regressions, notification previews, and the `scripts/package-release.py` workflow. Commit source changes and keep the working tree clean before packaging. Use the persistent `Asky Local Signing` certificate to produce a DMG, updater ZIP, and checksums. Record checks in `docs/validation/`.

### License

[MIT](LICENSE). Third-party dependencies retain their own licenses.

[中文](#中文) · [Back to top](#asky)
