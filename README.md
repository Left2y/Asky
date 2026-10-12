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

Asky 使用 SwiftUI 与 AppKit 构建，提供菜单栏入口、聚焦搜索、剪贴板历史和 AI 对话。搜索与本地工具独立运行；AI 是按需启用的增强能力。

应用、工程与 scheme 统一为 `Asky`，构建产物为 `Asky.app`，MCP 可执行文件为 `asky-mcp`。为兼容现有安装，沿用原有 bundle identifier、数据目录与钥匙串标识。新 MCP 配置使用 `ASKY_MCP_CREDENTIAL` / `ASKY_MCP_SOCKET`；旧环境变量及 App 内的 `kulahere-mcp` 命令路径继续可用。

项目处于开发阶段，仓库包含原生 App、Swift 核心包、TypeScript Agent Runtime 和 MCP Bridge。系统权限、模型兼容性及完整交互流程仍需在实际环境中验收。

### 核心能力

- **聚焦搜索**：搜索应用、文件、Chrome 标签页与本地书签，读取应用自带的本地化名称（含系统应用的 `InfoPlist.loctable`），支持应用别名、网页关键词、计算和换算。
- **剪贴板历史**：独立面板浏览文本与图片，悬停 1 秒后显示完整预览，支持固定、删除和键盘选择；授予辅助功能权限后可直接粘贴。
- **AI 对话**：支持 OpenAI 兼容接口、对话历史、图片与文件附件，以及原生 Markdown 排版。Agent 辅助进程按需启动，空闲后退出。每条任务最多自动调用 50 次工具。工具调用中显示加载动画，成功后显示对应来源图标，失败时显示带圈的叉；错误详情默认折叠，点击右侧箭头展开。
- **联网搜索**：AI 内置 `web_search`，无需额外 Key，通过 Bing 网页搜索返回标题、来源链接和摘要；在“设置 › 数据来源 › 联网搜索”关闭。搜索词会发送至 Bing，摘要发送至配置的模型服务。网页限流、验证或结构变化会明确报错；摘要不代表已读取全文。
- **系统工具**：通过 ToolService 统一处理系统读写与授权；集成日历、提醒事项、备忘录和通讯录，信息草稿交由系统 App 确认发送。
- **GitHub 插件**：在“设置 › 插件”按需安装官方或自行选择的公开 GitHub 仓库，支持配置、启停、更新、回退和卸载。官方 [Orca 插件](https://github.com/Niall-Young/asky-plugin-orca) 与 [飞书插件](https://github.com/Niall-Young/asky-plugin-lark) 独立发布，不进入安装包；插件会执行可信本机代码，不提供沙箱。支持清单自定义图标，Orca 使用本机应用图标，缺省时显示内置占位图标。接口与安装依赖见[插件指南](docs/plugins.md)。
- **MCP 扩展**：通过独立授权的 MCP Bridge 向外部客户端提供本地工具。

Markdown 回复支持 HTTP／HTTPS 图片、表格和代码块；图片按比例缩放，加载失败可重试，右下角按钮可将原图保存到 Downloads。代码块显示语言标题和复制按钮；表格保留外框、内部仅横线，Neutral 表头与 32 pt 单行高度，超宽内容可横向滚动。排版使用应用语义主题，随浅色／深色外观切换；图片下载上限 10 MiB，内存缓存上限 32 MiB，不读取 Markdown 中的本地文件图片。

### 快速开始

[下载 Asky 0.0.14](https://github.com/Niall-Young/Asky/releases/tag/v0.0.14)：适用于 macOS 15+、Apple Silicon。打开 DMG，将 `Asky.app` 拖入旁边的“应用程序”入口，再从“应用程序”启动；包内已包含 Node.js 与 AgentRuntime。若从 DMG 或下载目录直接启动，应用会先提示“安装并重新打开”；已有安装时提供打开已安装版本，不覆盖旧应用。ZIP 保留供应用内更新使用。此测试版使用 ad-hoc 签名，未经 Apple 公证，首次打开可能触发系统安全提示。

源码开发版本的运行目标为 macOS 15+（旧系统实机验收待完成）；开发需要 Xcode 26（Swift 6.2 或更新版本）、Node.js 22 或更新版本，以及 XcodeGen。

在仓库根目录运行以下命令，构建开发版本：

```sh
(cd AgentRuntime && npm ci && npm run build)
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/Asky.app
```

开发版可用 `open -n build/DerivedData/Build/Products/Debug/Asky.app --args --test-notification` 发送一条真实的 Asky 测试通知（5 秒后交付，带默认声音与“查看依据 / 已处理”操作，不创建日程或提醒计划）。在系统设置 › 通知 › Asky 开启声音，并选择“持续”提醒样式，可预览一直保留到操作的效果。日常智能建议仍默认无声；Release 构建不响应此参数。

### 使用方法

- 未输入时，搜索框与右侧两个等高圆形玻璃按钮合计占用原来的 720 pt 宽度；开始输入后按钮收起，搜索框恢复全部宽度。默认不固定、搜索全部。Pin 保持窗口在切换应用时可见，Filter 可限定应用、文件、快捷方式（内置网页指令与别名）或系统快捷指令。选择“全部”恢复混合搜索；Escape 先关闭筛选菜单，再关闭窗口，固定状态也可关闭。筛选与固定状态在窗口关闭后重置。
- 从菜单栏打开搜索，输入应用名、文件名或网页关键词，使用方向键选择、回车打开。
- `go`（Google 搜索）、`chat`（ChatGPT）、`yt`（YouTube）、`dy`（抖音）、`tb`（淘宝）、`jd`（京东）、`bl`（bilibili）、`gh`（GitHub）和 `>`（终端）是固定内置指令，无需配置，不能添加、修改或删除。可在“设置 › 指令”查看带对应品牌 Logo 的内置指令并配置终端；设置列表、搜索框与指令结果统一使用 24 × 24 pt、6 pt 圆角图标，周围留白透明、不添加底板或描边，`>` 显示当前所选终端的图标。旧的网页关键词配置不再参与启动器路由；输入 `go 内容`、`chat 问题` 或 `yt 搜索内容` 等即可使用。
- 输入英文 `>` 后按空格进入终端模式，例如 `> pwd`；单独的 `>` 或 `>pwd` 保持普通搜索；回车打开所选终端，在配置的工作目录执行命令。在“设置 › 指令 › 终端 › 执行命令的终端”选择已安装的系统终端、iTerm2 或 Ghostty（1.3+），入口与结果显示对应应用图标。输入框为空时按退格退出终端模式；首次使用可能需要授予自动化权限。
- 在“设置 › 系统权限 › Chrome 书签与链接搜索”查看访问状态，点击“去授权”并在系统选择器中选择 Chrome 文件夹或其 Default／Profile 个人资料文件夹；选择器默认定位到 Chrome，保存授权前会校验书签是否可读。未授权时，不显示链接和书签搜索入口或结果，`bm` 不进入书签模式；授权后重新打开启动器恢复这两项功能，输入 `bm 关键词` 搜索书签。仅读取本地和账号书签，不读取浏览历史。
- 在“设置 › 通用 › 文件搜索范围”点击“选择文件夹…”，通过系统文件夹选择窗口添加搜索目录。
- 输入 `1+1`，输入框末尾以浅色显示 `= 2`，下方卡片上下显示公式与结果：上方公式左对齐，下方结果右对齐，回车复制结果；长算式最多显示两行并从中间截断，悬停查看全文。输入 `1美元` 或 `100人民币`，下方横向展示输入币种与人民币的换算卡片（人民币输入默认换算为美元），其他币种保持列表显示在卡片下方。输入 `100 USD CNY` 可只查看指定币种。卡片显示旗帜、币种和金额，不提供选中、悬停或复制操作。汇率使用 ECB 日参考数据；断网时使用已有缓存，无缓存则显示不可用。
- 使用 `Ctrl + Option + Command + V` 打开剪贴板面板；可在“设置 › 触发快捷键”中修改快捷键。
- 使用 `Ctrl + Option + Command + /` 直接打开 AI 并开启空白新对话（无需 Shift）；可在“设置 › 触发快捷键 › AI 对话”中录制自定义组合键或恢复默认；正在回复时先取消旧任务。也可从菜单栏打开“AI 对话”，或在搜索中选择 AI 条目后提交。
- 启动器、AI 对话、剪贴板及玻璃浮层在 macOS 26+ 使用原生 Regular 液态玻璃；启动器与剪贴板绘制随明暗模式调整的外形阴影，并预留透明边距以避免裁切；其他浮窗保留系统窗口阴影；macOS 15 使用系统实时背景模糊、`background` 颜色变量和 1pt `border` 描边，设置侧栏与内容区同步适配。原生模糊半径由系统控制，不固定为 120px；在 macOS 辅助功能中开启“降低透明度”或“增强对比度”后，改用不透明背景和清晰边框。
- 搜索框或剪贴板面板获得焦点时，按 `⌘,` 打开设置。设置窗口采用原生侧边栏导航，右侧显示分组配置列表，并支持调整窗口大小。应用主题位于“通用 › 外观”。
- 在“设置 › 关于 Asky”查看当前版本并点击“检查更新”，应用会读取 GitHub `Niall-Young/Asky` 的最新 Release；GitHub API 限流（403/429）时自动改用公开 Release 网页，并在冷却期间避免重复请求 API。版本高于当前版本时可点击“安装更新”：下载 ZIP 并按 `.sha256` 校验、验证签名，完成 AI 辅助进程清理并退出 Asky 后，用新版本替换并删除旧版本，再自动重新打开。应用所在目录需可写；临时转移路径运行时需先移到“应用程序”。
- 在“设置 › 关于作者”查看作者邮箱、GitHub 主页和 X；点击邮箱打开默认邮件应用，点击 GitHub 或 X 打开默认浏览器。
- 应用语言位于“设置 › 通用 › 语言”，默认跟随 macOS 首选语言，也可选择简体中文或 English；更改在下次启动时生效。界面翻译使用原生 `.lproj` 资源，macOS 不会自动翻译应用自定义文字；AI 回复和用户内容不受此设置控制。

### 配置与隐私

**Asky 当前版本没有向项目作者上传用户数据的接口。剪贴板、对话、文件与系统资料不会通过应用上传到作者服务器；AI 请求直接发送到你配置的模型服务。** 作者可能收到你主动提交的 Issue、日志或截图，请先脱敏。

详见[隐私政策草案](PRIVACY.md)，包括本机保存、第三方处理和当前删除限制。正式发布前需补全主体、联系方式及应用内告知；状态见[隐私发布核查记录](docs/validation/2026-10-11-privacy-policy.md)。

使用 AI 前，在“设置 › 模型设置”中填写服务商的 API 地址、模型名和 API Key。Key 存储在 macOS 钥匙串中；本地数据位于 `~/Library/Application Support/KulaHere/`。

系统权限在“设置 › 系统权限”中管理，相关工具按需请求授权。日历、提醒事项、通讯录与通知使用请求结果立即刷新状态，过期的后台检查不会覆盖新结果。辅助功能和屏幕录制点击“去授权”后打开独立的原生玻璃浮窗，并自动打开对应系统权限页。未授权时浮窗先清除本应用该项的旧条目（ad-hoc 签名下旧构建留下的条目显示已开启却不生效，且会让系统设置拒绝再次拖入），清除完成后才开放拖拽卡片；将浮窗中的 Asky.app 卡片拖入系统设置即可添加并开启，不触发系统权限弹窗。重新授权时先删除旧条目再拖入。屏幕录制开启后需重启才生效，浮窗随后提供“重新启动 Asky”。拖动开始时原位卡片隐藏，取消或未被接收时恢复，被接收后保持隐藏。浮窗持续检查当前应用进程的权限，确认授权后自动关闭，并关闭或收起本次权限页；若已切到其他系统设置页，则保留该页面。临时转移路径运行的应用需先移到“应用程序”并重新打开。AI 请求会将提交的消息、附件及所需工具结果发送到配置的模型服务。使用前请确认该服务的数据处理方式。

日历与提醒事项工具会在系统授权变化后刷新 EventKit 数据实例。若系统未返回任何日历或提醒列表，会先尝试刷新，再报告无法确认的数据读取异常，不据此断言账户未配置；搜索无匹配与读取失败分别处理。

在设置 › 数据来源中点击「连接备忘录」，完成系统授权后自动列出账户与文件夹（包含子文件夹）。勾选允许访问的文件夹后自动保存；「刷新文件夹」重新加载列表，授权失败时可直接打开自动化权限设置。发现文件夹仅读取名称和标识，备忘录正文仍只在勾选范围内访问。

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
python3 App/Tests/run-launcher-window-regression.py --bottom-clearance
python3 App/Tests/run-launcher-window-regression.py --accessories
python3 App/Tests/run-launcher-window-regression.py --command-icons
python3 App/Tests/run-launcher-terminal-regression.py
python3 App/Tests/run-launcher-calculation-regression.py
python3 App/Tests/run-launcher-window-regression.py --ai-routing
python3 App/Tests/run-launcher-window-regression.py --system-app-names
python3 App/Tests/run-launcher-window-regression.py --alias-routing
python3 App/Tests/run-launcher-window-regression.py --bookmarks
python3 App/Tests/run-clipboard-regression.py
python3 App/Tests/run-clipboard-regression.py --hover-delay
python3 App/Tests/run-clipboard-regression.py --hover-mouse
python3 App/Tests/run-clipboard-regression.py --settings-shortcut
python3 App/Tests/run-clipboard-regression.py --drag
python3 App/Tests/run-clipboard-regression.py --drag-preview
python3 App/Tests/run-settings-regression.py
python3 App/Tests/run-settings-regression.py --permissions-only
python3 App/Tests/run-settings-regression.py --preview-legacy-material
python3 App/Tests/run-settings-regression.py --plugins-only -AppleLanguages "(en)"
python3 App/Tests/run-application-language-regression.py -AppleLanguages "(en)"
python3 App/Tests/run-application-language-regression.py -AppleLanguages "(zh-Hans)"
python3 App/Tests/run-agent-reply-regression.py
python3 App/Tests/run-application-termination-regression.py
```

剪贴板 `--drag` 检查真实鼠标拖放与未固定面板关闭；`--drag-preview` 保留带测试卡片的未固定面板供人工拖放。设置 `ASKY_CLIPBOARD_DROP_POINT=x,y` 可将 `--drag` 目标改为屏幕坐标下的外部输入框，搭配 `ASKY_CLIPBOARD_DRAG_IMAGE=1` 拖第二张图片卡片；外部目标内容需另行回读确认。

启动器 `--bottom-clearance` 专项检查列表滚动、键盘首尾导航与最后一项的底部留白，覆盖亮暗模式；不运行系统事件投递与异步搜索时序检查。

并行构建时，启动器与设置回归脚本支持用 `ASKY_DERIVED_DATA` 指定独立的 DerivedData 目录，默认使用 `build/DerivedData`。启动器同时隔离回归产物；设置脚本兼容旧变量 `KULAHERE_DERIVED_DATA`。

原生输入框与快捷键的独立检查：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/LauncherSearchField.swift App/Sources/EditMenu.swift App/Tests/LauncherSearchFieldRegression.swift -o build/launcher-input-regression
build/launcher-input-regression
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/HotKey.swift App/Tests/HotKeyRegression.swift -o build/hotkey-regression
build/hotkey-regression
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/ConversationSearchField.swift App/Tests/ConversationSearchFieldRegression.swift -o build/conversation-search-regression
build/conversation-search-regression
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse-as-library -swift-version 6 App/Sources/OutsideClickDismissal.swift App/Tests/OutsideClickDismissalRegression.swift -o build/outside-click-regression
build/outside-click-regression
```

检查结果按实际运行情况记录在 `docs/validation/`。自动化检查与真实系统权限、模型和界面验收分别记录。

### 发布打包

0.0.14 修复启动器列表最后一项底部留白，并消除末项强制对齐导致的滚动顿挫；同时修复汇率结果出现前的 AI 兜底闪烁，补齐启动器圆形按钮阴影。保留 0.0.13 的浮窗、剪贴板预览和书签授权修复，以及更新退出重启与 GitHub API 限流时的公开 Release 网页回退。0.0.8 的旧退出流程仍可能卡住，首次升级请退出旧应用，再用 DMG 将新应用替换到“应用程序”；真实应用内升级仍需验证。

先运行上面的测试，使用 `xcodebuild` 的 `Release` 配置构建到 `build/Release014DerivedData`。在干净的 `build/release-runtime-0.0.14` 目录中仅放入 AgentRuntime 的 `dist`、`package.json`、`package-lock.json`，再运行 `npm ci --omit=dev --prefix build/release-runtime-0.0.14`。从 Node.js 官方获取并按官方 SHA-256 清单核验 arm64 运行时，解压至下面的目录。提交源码后，在干净工作区运行：

```sh
python3 scripts/package-release.py --version 0.0.14 --build 14 \
  --derived-data build/Release014DerivedData \
  --runtime build/release-runtime-0.0.14 \
  --node-root build/release-node-0.0.14/node-v22.23.3-darwin-arm64
```

脚本生成 `build/releases/0.0.14/` 下的 DMG、更新用 ZIP 及各自的 `.sha256`，校验签名并检查随包 runtime 的启动协议。它使用 ad-hoc 签名，不执行公证、GitHub 发布或本机安装；每次打包需要新的 staging 目录。DMG 使用 `scripts/dmg/background.tiff` 的 Retina 背景与 `scripts/dmg/layout.applescript` 的固定图标布局；打包会短暂打开 Finder 写入布局，终端需获准自动化 Finder。

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
- **Clipboard history**: Browse text and images in a dedicated panel with full previews after hovering for 1 second, pinning, deletion, and keyboard selection. Direct paste requires Accessibility permission.
- **AI conversations**: Use OpenAI-compatible APIs with conversation history, image and file attachments, and native Markdown rendering. The agent helper starts on demand and exits when idle. Each task allows up to 50 automatic tool calls. Tool calls show a spinner while running, their source icon on success, and a circled cross on failure; error details start collapsed and can be expanded with the arrow on the right.
- **Web search**: The AI includes `web_search` with no extra key, returning titles, source links, and snippets from Bing web search. Disable it under Settings › Sources › Web Search. Queries go to Bing and snippets to your configured model provider. Rate limits, verification challenges, and page structure changes produce explicit errors; snippets are not full-page reads.
- **System tools**: ToolService manages system reads, writes, and authorization. Integrations cover Calendar, Reminders, Notes, and Contacts; message drafts are handed to the system app for confirmation and sending.
- **GitHub plugins**: Install official or user-selected public GitHub repositories under Settings › Plugins, with configuration, enable/disable, updates, rollback, and uninstall. The official [Orca plugin](https://github.com/Niall-Young/asky-plugin-orca) and [Lark plugin](https://github.com/Niall-Young/asky-plugin-lark) ship separately and are not bundled. Plugins support custom manifest icons, use the local Orca app icon, and show a bundled placeholder when no artwork is available. Plugins run trusted local code without a sandbox; see the [plugin guide](docs/plugins.md) for the API and installation prerequisites.
- **MCP extensions**: Expose local tools to external clients through a separately authorized MCP Bridge.

Markdown replies support HTTP/HTTPS images, tables, and code blocks. Images preserve their aspect ratio, failed loads can be retried, and the bottom-right button saves originals to Downloads. Code blocks show language headers and copy buttons; tables keep their outer borders and horizontal separators, with neutral headers, 32 pt single-line rows, and horizontal scrolling for wide content. Rendering follows the app’s semantic light/dark theme, with a 10 MiB image download limit and 32 MiB memory cache; local file images in Markdown are not read.

### Quick Start

[Download Asky 0.0.14](https://github.com/Niall-Young/Asky/releases/tag/v0.0.14) for macOS 15+ on Apple Silicon. Open the DMG, drag `Asky.app` onto the Applications shortcut, then launch it from Applications. Node.js and AgentRuntime are included. Launching from the DMG or Downloads first offers Install and Reopen; when an installation already exists, it offers to open that version without overwriting it. The ZIP remains available for in-app updates. This test build is ad-hoc signed and has not been notarized by Apple, so first launch may trigger a system security prompt.

Source builds target macOS 15+ (verification on an older OS is pending). Development requires Xcode 26 (Swift 6.2 or later), Node.js 22 or later, and XcodeGen.

Run these commands from the repository root to build the development app:

```sh
(cd AgentRuntime && npm ci && npm run build)
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/Asky.app
```

In a Debug build, run `open -n build/DerivedData/Build/Products/Debug/Asky.app --args --test-notification` to deliver a real Asky test notification after 5 seconds, with the default sound and “View Evidence / Handled” actions. It creates no calendar items or reminder plans. Enable sound and select the persistent alert style under System Settings › Notifications › Asky to preview an alert that stays until acted on. Everyday smart suggestions remain silent; Release builds ignore this argument.

### Usage

- View access under Settings › System Permissions › Chrome bookmarks and link search. Click “Grant Access” and select the Chrome folder or its Default / Profile folder in the system picker. The picker starts in Chrome and verifies bookmark access before saving the grant. Without access, link and bookmark search entries and results are hidden, and `bm` cannot enter bookmark mode. After authorization, reopen the launcher to enable both features; enter `bm query` to search bookmarks. Only local and account bookmarks are read, never browsing history.
- With no input, the search field and two circular glass buttons share the original 720 pt width. Typing hides the buttons and returns the full width to search. Each invocation defaults to unpinned with all sources. Pin keeps the window visible when switching apps; Filter limits results to applications, files, Quick Links (built-in web commands and aliases), or system Shortcuts. All restores mixed search. Escape closes the filter menu first, then the window, including pinned windows. Closing the window resets both filter and pin state.
- Open search from the menu bar, enter an app name, file name, or web keyword, select with the arrow keys, and press Return to open.
- Type `1+1` to see a faint `= 2` suffix and a stacked card with the expression aligned left above the right-aligned result; press Return to copy the result. Long expressions occupy up to two lines with middle truncation; hover to see the full expression. Type `1美元`, `1 USD`, or `100人民币` to see a horizontal pair of cards showing the input currency and Chinese yuan (yuan inputs default to US dollars), with all other currencies listed underneath. Use `100 USD CNY` for a specific pair. Cards show flags, currencies, and amounts, without selection, hover, or copy actions. Rates use ECB daily references; offline use falls back to the cache or reports unavailable.
- `go` (Google search), `chat` (ChatGPT), `yt` (YouTube), `dy` (Douyin), `tb` (Taobao), `jd` (JD), `bl` (bilibili), `gh` (GitHub), and `>` (terminal) are fixed built-in commands that require no setup and cannot be added, edited, or deleted. View built-in commands with their brand logos and configure the terminal under Settings › Commands. Settings, the search field, and command results share 24 × 24 pt icons with 6 pt corners, transparent surrounding space, and no added background or border; `>` shows the selected terminal’s icon. Legacy web keyword settings no longer affect launcher routing; type `go query`, `chat question`, or a site shortcut such as `yt query` to use them.
- Type ASCII `>` followed by a space to enter terminal mode, for example `> pwd`; `>` alone or `>pwd` stays in ordinary search; Return opens the selected terminal and runs the command in the configured working directory. Choose an installed system Terminal, iTerm2, or Ghostty (1.3+) under Settings › Commands › Terminal › Terminal for Commands; the launcher and result show that app’s icon. Backspace on an empty field leaves terminal mode. First use may require Automation permission.
- Under Settings › General › File Search Scope, click “Choose Folder…” to add a search directory using the system folder picker.
- Press `Ctrl + Option + Command + V` to open clipboard history. Customize it under Settings › Trigger Shortcuts.
- Press `Ctrl + Option + Command + /` to open AI with a blank new conversation (without Shift); customize the combination or restore its default in Settings › Hotkeys › AI Conversation; an active reply is cancelled first. You can also open AI Conversation from the menu bar, or select and submit the AI entry in search.
- On macOS 26+, the launcher, AI conversations, clipboard and glass overlays use native Regular Liquid Glass. The launcher and clipboard render an appearance-aware shape-based outer shadow with transparent margins to prevent clipping; other floating windows retain system window shadows. On macOS 15, they use live system background blur, the `background` color token and a 1pt `border` outline; the settings sidebar and content area use the same fallback. The system controls the native blur radius rather than a fixed 120px. Enabling Reduce Transparency or Increase Contrast in macOS Accessibility switches them to opaque backgrounds with clear borders.
- Press `⌘,` to open Settings while the search field or clipboard panel has focus. Settings uses native sidebar navigation with grouped configuration lists on the right and a resizable window. The app theme is under General › Appearance.
- Under Settings › About Asky, view the current version and click Check for Updates to read the latest GitHub release of `Niall-Young/Asky`. If the GitHub API is rate limited (403/429), it falls back to the public Release page and avoids further API requests during the cooldown. When it is newer than the running app, Install Update downloads the ZIP, verifies its `.sha256` checksum and code signature, stops the AI runtime and quits Asky, replaces and deletes the old version, then reopens it. The app folder must be writable; a translocated app must first be moved to Applications.
- Under Settings › About the Author, find the author’s email, GitHub profile, and X profile. Click the email to open your default email app, or GitHub / X to open your default browser.
- App language is under Settings › General › Language. It follows the preferred macOS language by default, with Simplified Chinese and English overrides; changes take effect on the next launch. Interface translations use native `.lproj` resources; macOS does not automatically translate custom app text. This setting does not control AI replies or user content.

### Configuration and Privacy

**The current version of Asky has no endpoint that uploads user data to the project author. Clipboard contents, conversations, files, and system data are not uploaded by the app to an author-operated server; AI requests go directly to your configured model service.** The author may receive issues, logs, or screenshots you submit voluntarily; redact them first.

See the [draft privacy policy (Chinese)](PRIVACY.md) for local storage, third-party processing, and current deletion limits. Publisher details, privacy contact information, and in-app notices must be completed before release; see the [privacy release review (Chinese)](docs/validation/2026-10-11-privacy-policy.md).

Before using AI, enter your provider's API endpoint, model name, and API key under Settings › Model Settings. Keys are stored in macOS Keychain; local data resides in `~/Library/Application Support/KulaHere/`.

Manage system permissions under Settings › System Permissions. Tools request authorization as needed. Calendar, Reminders, Contacts, and Notifications update immediately from the request result; stale background checks cannot overwrite it. For Accessibility and Screen Recording, click Grant Access to open an independent native glass panel and the matching System Settings pane automatically. When access is missing, the panel clears this app’s old entry, then enables the drag card. Dragging the Asky.app card into System Settings adds and enables it without a system permission prompt. Screen recording may require restarting Asky; the panel offers a restart button. To grant access again, remove the old entry before dragging. The source card disappears when dragging starts, returns if the drag is cancelled or rejected, and stays hidden after an accepted drop. The panel keeps checking the running app’s access and closes when authorization is confirmed, also closing or hiding its permission pane; a different pane you have navigated to is preserved. A translocated app must first be moved to Applications and reopened. AI requests send submitted messages, attachments, and required tool results to the configured model service. Review that service's data handling before use.

Under Settings › Sources, click Connect Notes to authorize Apple Notes and automatically list accounts and folders, including nested folders. Select the folders Asky may access; selections are saved automatically. Refresh reloads the list, and authorization errors provide a link to Automation settings. Folder discovery reads names and identifiers only; note content remains limited to selected folders.

Calendar and Reminders tools refresh their EventKit store after system authorization changes. If no calendars or reminder lists are returned, they attempt a refresh and then report an unconfirmed data-access issue rather than claiming the account is unconfigured; an empty search and a read failure remain distinct.

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
python3 App/Tests/run-launcher-window-regression.py --bottom-clearance
python3 App/Tests/run-launcher-window-regression.py --accessories
python3 App/Tests/run-launcher-window-regression.py --command-icons
python3 App/Tests/run-launcher-terminal-regression.py
python3 App/Tests/run-launcher-calculation-regression.py
python3 App/Tests/run-launcher-window-regression.py --ai-routing
python3 App/Tests/run-launcher-window-regression.py --system-app-names
python3 App/Tests/run-launcher-window-regression.py --alias-routing
python3 App/Tests/run-launcher-window-regression.py --bookmarks
python3 App/Tests/run-clipboard-regression.py
python3 App/Tests/run-clipboard-regression.py --hover-delay
python3 App/Tests/run-clipboard-regression.py --hover-mouse
python3 App/Tests/run-clipboard-regression.py --settings-shortcut
python3 App/Tests/run-clipboard-regression.py --drag
python3 App/Tests/run-clipboard-regression.py --drag-preview
python3 App/Tests/run-settings-regression.py
python3 App/Tests/run-settings-regression.py --permissions-only
python3 App/Tests/run-settings-regression.py --preview-legacy-material
python3 App/Tests/run-settings-regression.py --plugins-only -AppleLanguages "(en)"
python3 App/Tests/run-application-language-regression.py -AppleLanguages "(en)"
python3 App/Tests/run-application-language-regression.py -AppleLanguages "(zh-Hans)"
python3 App/Tests/run-agent-reply-regression.py
python3 App/Tests/run-application-termination-regression.py
```

Clipboard `--drag` checks a real mouse drop and unpinned panel dismissal; `--drag-preview` keeps an unpinned panel with test cards open for manual drops. Set `ASKY_CLIPBOARD_DROP_POINT=x,y` to target an external input at screen coordinates, and add `ASKY_CLIPBOARD_DRAG_IMAGE=1` to drag the second image card. Read back external destination contents separately to confirm the result.

Launcher `--bottom-clearance` checks list scrolling, keyboard navigation at both ends, and the final row's bottom clearance in light and dark modes. It skips system event delivery and asynchronous search timing checks.

For concurrent builds, the launcher and settings regression scripts accept `ASKY_DERIVED_DATA` to select an isolated DerivedData directory, defaulting to `build/DerivedData`. Launcher regression artifacts are isolated as well; the settings script also supports the legacy `KULAHERE_DERIVED_DATA` variable.

Standalone checks for native input fields and hotkeys:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/LauncherSearchField.swift App/Sources/EditMenu.swift App/Tests/LauncherSearchFieldRegression.swift -o build/launcher-input-regression
build/launcher-input-regression
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/HotKey.swift App/Tests/HotKeyRegression.swift -o build/hotkey-regression
build/hotkey-regression
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/ConversationSearchField.swift App/Tests/ConversationSearchFieldRegression.swift -o build/conversation-search-regression
build/conversation-search-regression
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse-as-library -swift-version 6 App/Sources/OutsideClickDismissal.swift App/Tests/OutsideClickDismissalRegression.swift -o build/outside-click-regression
build/outside-click-regression
```

Record only checks actually executed in `docs/validation/`. Track automated checks separately from acceptance testing of real system permissions, models, and interfaces.

### Release Packaging

Version 0.0.14 fixes bottom clearance for the final launcher result, removes scrolling stutter caused by forced final-row alignment, prevents AI fallback flicker before currency results appear, and restores shadows on the circular launcher buttons. It retains the floating-window, clipboard preview, and bookmark authorization fixes from 0.0.13, plus update quit/restart fixes and the public Release page fallback when the GitHub API is rate limited. The old quit flow in 0.0.8 can still hang; quit the old app and replace it in Applications using the DMG for this first upgrade. The real in-app upgrade remains to be verified.

Run the tests above and build with the `Release` configuration of `xcodebuild` into `build/Release014DerivedData`. In a clean `build/release-runtime-0.0.14` directory, include only AgentRuntime's `dist`, `package.json`, and `package-lock.json`, then run `npm ci --omit=dev --prefix build/release-runtime-0.0.14`. Obtain the arm64 runtime from Node.js, verify it against the official SHA-256 manifest, and extract it into the directory below. Commit the source changes, then run from a clean working tree:

```sh
python3 scripts/package-release.py --version 0.0.14 --build 14 \
  --derived-data build/Release014DerivedData \
  --runtime build/release-runtime-0.0.14 \
  --node-root build/release-node-0.0.14/node-v22.23.3-darwin-arm64
```

The script creates a DMG, an updater ZIP, and their `.sha256` files under `build/releases/0.0.14/`, verifies the signature, and checks the bundled runtime startup protocol. It uses ad-hoc signing and does not notarize, publish to GitHub, or install locally. Each packaging run requires a new staging directory. The DMG uses the Retina background in `scripts/dmg/background.tiff` and the fixed icon layout in `scripts/dmg/layout.applescript`. Packaging briefly opens Finder to save the layout and requires the terminal to have permission to automate Finder.

### License

This project is licensed under the [MIT License](LICENSE), which permits use, modification, distribution, and commercial use, including closed-source derivatives. Copies or substantial portions of the software must retain the copyright and permission notices. The software is provided as is, without warranty.

Third-party dependencies and their bundled resources remain subject to their respective licenses; this project's MIT license does not replace those terms.

[中文](#中文) · [Back to top](#asky)
