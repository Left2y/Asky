# Asky 开发与发布 / Development and Releases

[中文](#中文) | [English](#english) · [README](../README.md)

<a id="中文"></a>
## 中文

### 回归检查

以下命令均从仓库根目录运行。先构建 MCP Bridge，再运行核心包测试：

```sh
(cd AgentRuntime && npm test)
(cd MCPBridge && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build)
(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)
```

完成[README](../README.md) 中的 Debug 构建后，可运行原生回归检查。部分交互检查需要系统输入事件权限：

```sh
python3 App/Tests/run-launcher-window-regression.py
python3 App/Tests/run-launcher-window-regression.py --bottom-clearance
python3 App/Tests/run-launcher-window-regression.py --compact-results
python3 App/Tests/run-launcher-window-regression.py --result-motion
python3 App/Tests/run-launcher-window-regression.py --accessories
python3 App/Tests/run-launcher-window-regression.py --command-icons
python3 App/Tests/run-launcher-terminal-regression.py
python3 App/Tests/run-launcher-calculation-regression.py
python3 App/Tests/run-launcher-window-regression.py --ai-routing
python3 App/Tests/run-launcher-window-regression.py --system-app-names
python3 App/Tests/run-launcher-window-regression.py --alias-routing
python3 App/Tests/run-launcher-window-regression.py --bookmarks
python3 App/Tests/run-clipboard-regression.py
python3 App/Tests/run-clipboard-regression.py --paste-target
python3 App/Tests/run-clipboard-regression.py --drag-paste-target
python3 App/Tests/run-clipboard-regression.py --hover-delay
python3 App/Tests/run-clipboard-regression.py --hover-mouse
python3 App/Tests/run-clipboard-regression.py --settings-shortcut
python3 App/Tests/run-clipboard-regression.py --drag
python3 App/Tests/run-clipboard-regression.py --files
python3 App/Tests/run-clipboard-regression.py --chat-images
python3 App/Tests/run-clipboard-regression.py --drag-preview
python3 App/Tests/run-settings-regression.py
python3 App/Tests/run-settings-regression.py --permissions-only
python3 App/Tests/run-settings-regression.py --preview-legacy-material
python3 App/Tests/run-settings-regression.py --plugins-only -AppleLanguages "(en)"
python3 App/Tests/check-localization.py
python3 App/Tests/run-application-language-regression.py -AppleLanguages "(en)"
python3 App/Tests/run-application-language-regression.py -AppleLanguages "(zh-Hans)"
python3 App/Tests/run-agent-reply-regression.py
python3 App/Tests/run-application-termination-regression.py
```

Debug 主应用可用 `open -n build/DerivedData/Build/Products/Debug/Asky.app --args --test-clipboard` 打开固定的正式剪贴板面板，用于跨应用拖放验收；可通过 `ASKY_CLIPBOARD_TEST_QUERY` 环境变量筛选测试卡片。该模式只记录拖拽类型、数量及接受结果，不记录内容或路径。验证前退出其他 Asky 实例，尤其是 `/Applications/Asky.app` 的旧版本，避免快捷键竞争及误测旧面板。

使用 `open -n build/DerivedData/Build/Products/Debug/Asky.app --args --test-confirmations` 依次预览飞书插件、日历、信息和外部 MCP 的共用系统确认弹窗。每项确认或取消后进入下一项，随后预览插件安装、应用更新与错误提示，完成后退出；不启动 AI 或执行真实工具。

应用内确认和提示共用带 Asky 图标的原生系统弹窗。操作确认默认展示自然语言动作与关键内容，工具名和完整参数放在可展开的“操作详情”中；系统权限窗口与文件选择器保持系统样式。

AI 对话框发送按钮旁可切换全局审批模式，修改后对所有对话持续生效。默认“自动审批”：查询和明确要求的创建直接执行，修改、删除、发送等风险操作弹窗确认，AI 自行推断的写入只作为建议。“完全访问权限”下 AI 的所有工具调用直接执行、不再询问。该模式只影响 Asky 内的 AI 对话；启动器和外部 MCP 调用始终按原规则确认，数据来源开关和系统授权检查也照常生效。

剪贴板 `--drag-paste-target` 使用独立进程中拒绝原生拖放的编辑器，回读补粘贴结果，并检查 Esc 取消和非输入区域不改写剪贴板。`--chat-images` 检查图片与文件名混合载荷、临时图片文件、缩略图和原图再次复制。`--files` 检查文件监听、整组复制和真实鼠标文件拖放，并回读接收文件的内容；`--drag` 检查真实鼠标拖放与未固定面板关闭；`--drag-preview` 保留带测试卡片的未固定面板供人工拖放。`--external-drag` 使用单条 `AskyDragProbe` 测试文本，通过 `ASKY_CLIPBOARD_TARGET_BUNDLE` 激活指定的已运行应用，并按 `ASKY_CLIPBOARD_DROP_POINT=x,y`（Quartz 屏幕坐标）执行真实拖放；测试仅置入草稿，不发送消息，结果需在应用中回读并清理。设置 `ASKY_CLIPBOARD_DROP_POINT=x,y` 也可将 `--drag` 目标改为外部输入框，搭配 `ASKY_CLIPBOARD_DRAG_IMAGE=1` 拖第二张图片卡片；外部目标内容需另行回读确认。

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

### 本地化资源

App 界面资源位于 `App/Resources`；核心错误、工具说明及确定性提醒通过 `Contracts/CoreLocalization` 读取 SwiftPM 资源包 `KulaCore_Contracts.bundle` 中的 `Core.strings`。两个语言必须同步添加键，并保留格式参数与用户内容。固定错误不要直接拼接中文字符串。

原生 App 按启动时选中的语言读取资源；设置改动仍在重启后生效。独立 MCP Bridge 使用自己的启动语言或系统语言。Xcode 与 SwiftPM 自动打包共享资源，原生回归脚本通过 `regression_resources.py` 复制相同资源包。测试不得用中文内容来判断流程是否结束。

确认请求的内部字段标记、输入别名、持久化字段和用户内容保持原有契约，展示层负责翻译。第三方原始错误作为参数保留。

### 发布打包

版本变更与发布结果见 [0.1.0 发布记录](validation/2026-10-14-release-0.1.0.md)。以下路径为该版本的打包示例；发布新版本时替换版本号、构建号及目录。

先运行本指南中的测试，使用 `xcodebuild` 的 `Release` 配置构建到 `build/Release010DerivedData`。在干净的 `build/release-runtime-0.1.0` 目录中仅放入 AgentRuntime 的 `dist`、`package.json`、`package-lock.json`，再运行 `npm ci --omit=dev --prefix build/release-runtime-0.1.0`。从 Node.js 官方获取并按官方 SHA-256 清单核验 arm64 运行时，解压至下面的目录。提交源码后，在干净工作区运行：

```sh
python3 scripts/package-release.py --version 0.1.0 --build 24 \
  --derived-data build/Release010DerivedData \
  --runtime build/release-runtime-0.1.0 \
  --node-root build/release-node-0.0.16/node-v22.23.3-darwin-arm64
```

开发与后续打包默认使用固定的 `Asky Local Signing` 自签名证书。首次运行 `python3 scripts/setup-local-signing.py`，证书有效期为 10 年，仅包含名称，不填写姓名或邮箱；私钥保存在登录钥匙串，临时私钥文件自动删除。系统可能要求确认钥匙串操作。重复运行保留原证书，不能每次更新重新创建；跨机器发布应安全迁移同一签名身份，私钥备份不得进入仓库或安装包。证书丢失、过期或换用另一身份时可能需要重新授权。签名身份连续性不等于各项系统权限已实机验收；从旧 ad-hoc 版本切换后可能需要重新授权一次。

脚本生成 `build/releases/0.1.0/` 下的 DMG、更新用 ZIP 及各自的 `.sha256`，校验签名并检查随包 runtime 的启动协议。它使用固定自签名身份（可通过 `--signing-identity` 指定其他证书名称或 SHA-1），缺少证书或指定 ad-hoc 时直接失败；不执行公证、GitHub 发布或本机安装；每次打包需要新的 staging 目录。DMG 使用 `scripts/dmg/background.tiff` 的 Retina 背景与 `scripts/dmg/layout.applescript` 的固定图标布局；打包会短暂打开 Finder 写入布局，终端需获准自动化 Finder。

### 短信日程配置回归

先按 README 完成 Debug 构建，再执行 `python3 App/Tests/run-calendar-editor-regression.py`。默认检查标题、时间、日历选择和字段传递；`--preview` 打开实际分组弹窗，使用示例日历且不写入真实日程；另加 `--preview-error` 模拟首次冲突，检查窗口保留输入并允许重试。日期行展开月历与数字小时、分钟下拉框，创建直接经 ToolService 保存，不再交接 ICS 或打开日历应用。

### 通知预览

Debug 参数 `--test-notification` 现在是 `--test-banner` 的兼容别名，均预览 Asky 自绘卡片，不再发送系统通知或请求通知权限；Release 不响应这两个参数。

Debug 版本可用 `open -n build/DerivedData/Build/Products/Debug/Asky.app --args --test-banner`，或菜单栏 › 预览提醒卡片，查看 Asky 自绘的提醒卡片：右上角浮层，不抢焦点。新卡片以 8pt 间隔向下排列，约 4 秒后折叠成层叠，只显示最前一张；点击露出的边缘可重新展开，逐张处理。悬停时暂停折叠和自动消失。它不进通知中心，也不创建日程。

---

<a id="english"></a>
## English

### Regression Checks

Run these commands from the repository root. Build the MCP Bridge before running core package tests:

```sh
(cd AgentRuntime && npm test)
(cd MCPBridge && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build)
(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)
```

After the Debug build in [README](../README.md), run native regression checks. Some interaction checks require system input event permissions:

```sh
python3 App/Tests/run-launcher-window-regression.py
python3 App/Tests/run-launcher-window-regression.py --bottom-clearance
python3 App/Tests/run-launcher-window-regression.py --compact-results
python3 App/Tests/run-launcher-window-regression.py --result-motion
python3 App/Tests/run-launcher-window-regression.py --accessories
python3 App/Tests/run-launcher-window-regression.py --command-icons
python3 App/Tests/run-launcher-terminal-regression.py
python3 App/Tests/run-launcher-calculation-regression.py
python3 App/Tests/run-launcher-window-regression.py --ai-routing
python3 App/Tests/run-launcher-window-regression.py --system-app-names
python3 App/Tests/run-launcher-window-regression.py --alias-routing
python3 App/Tests/run-launcher-window-regression.py --bookmarks
python3 App/Tests/run-clipboard-regression.py
python3 App/Tests/run-clipboard-regression.py --paste-target
python3 App/Tests/run-clipboard-regression.py --drag-paste-target
python3 App/Tests/run-clipboard-regression.py --hover-delay
python3 App/Tests/run-clipboard-regression.py --hover-mouse
python3 App/Tests/run-clipboard-regression.py --settings-shortcut
python3 App/Tests/run-clipboard-regression.py --drag
python3 App/Tests/run-clipboard-regression.py --files
python3 App/Tests/run-clipboard-regression.py --chat-images
python3 App/Tests/run-clipboard-regression.py --drag-preview
python3 App/Tests/run-settings-regression.py
python3 App/Tests/run-settings-regression.py --permissions-only
python3 App/Tests/run-settings-regression.py --preview-legacy-material
python3 App/Tests/run-settings-regression.py --plugins-only -AppleLanguages "(en)"
python3 App/Tests/check-localization.py
python3 App/Tests/run-application-language-regression.py -AppleLanguages "(en)"
python3 App/Tests/run-application-language-regression.py -AppleLanguages "(zh-Hans)"
python3 App/Tests/run-agent-reply-regression.py
python3 App/Tests/run-application-termination-regression.py
```

In the Debug app, `open -n build/DerivedData/Build/Products/Debug/Asky.app --args --test-clipboard` opens the pinned production clipboard panel for cross-app drag acceptance testing. Set `ASKY_CLIPBOARD_TEST_QUERY` to filter test cards. This mode logs only the dragged kind, item count, and acceptance result, with no contents or paths. Quit other Asky instances first, especially older copies of `/Applications/Asky.app`, to avoid hotkey conflicts and testing the wrong panel.

Use `open -n build/DerivedData/Build/Products/Debug/Asky.app --args --test-confirmations` to preview the shared system confirmation dialog for the Lark plugin, Calendar, Messages, and external MCP in sequence. Approving or cancelling advances to the next preview, followed by plugin installation, app update, and error alerts. The app exits after the last one. This mode does not start AI or execute real tools.

App-owned confirmations and alerts share native system dialogs with the Asky icon. Operation confirmations show readable actions and key content, with tool names and full arguments in expandable operation details. System permission dialogs and file pickers keep their system presentation.

Clipboard `--chat-images` checks mixed image/filename payloads, temporary image files, thumbnails, and copying the original image again. `--files` checks file monitoring, multi-file copying, real mouse dragging, and received file contents; `--drag` checks a real mouse drop and unpinned panel dismissal; `--drag-preview` keeps an unpinned panel with test cards open for manual drops. Set `ASKY_CLIPBOARD_DROP_POINT=x,y` to target an external input at screen coordinates, and add `ASKY_CLIPBOARD_DRAG_IMAGE=1` to drag the second image card. Read back external destination contents separately to confirm the result.

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

### Localization Resources

App interface resources live in `App/Resources`. Core errors, tool descriptions and deterministic reminders use `Contracts/CoreLocalization` to read `Core.strings` from the SwiftPM `KulaCore_Contracts.bundle`. Add keys in both languages, preserving format arguments and user content. Do not concatenate fixed Chinese error text directly.

The native app uses the language selected at launch; changes in Settings still take effect after restarting. The standalone MCP Bridge uses its launch or system language. Xcode and SwiftPM package the shared resources automatically, and native regression scripts copy the same bundle through `regression_resources.py`. Tests must not use Chinese wording to decide when a flow has finished.

Internal confirmation field markers, input aliases, persisted fields and user content retain their existing contracts; the presentation layer translates them. Raw third-party errors remain format arguments.

### Release Packaging

See the [0.1.0 release record](validation/2026-10-14-release-0.1.0.md) for changes and results. The paths below are examples for that version; replace the version, build number, and directories for a new release.

Run the tests in this guide and build with the `Release` configuration of `xcodebuild` into `build/Release010DerivedData`. In a clean `build/release-runtime-0.1.0` directory, include only AgentRuntime's `dist`, `package.json`, and `package-lock.json`, then run `npm ci --omit=dev --prefix build/release-runtime-0.1.0`. Obtain the arm64 runtime from Node.js, verify it against the official SHA-256 manifest, and extract it into the directory below. Commit the source changes, then run from a clean working tree:

```sh
python3 scripts/package-release.py --version 0.1.0 --build 24 \
  --derived-data build/Release010DerivedData \
  --runtime build/release-runtime-0.1.0 \
  --node-root build/release-node-0.0.16/node-v22.23.3-darwin-arm64
```

Development and future packages default to the persistent `Asky Local Signing` self-signed certificate. Run `python3 scripts/setup-local-signing.py` once. The certificate lasts 10 years and contains only its name, with no personal name or email. The private key stays in the login keychain; temporary private-key files are removed automatically. macOS may ask you to confirm keychain operations. Re-running preserves the certificate; do not recreate it for each update. To publish from another machine, securely migrate the same signing identity and keep private-key backups out of the repository and installers. Losing, expiring, or replacing the identity may require authorization again. Stable signing identity does not establish live acceptance of every system permission; switching from an old ad-hoc build may require authorization once.

The script creates a DMG, an updater ZIP, and their `.sha256` files under `build/releases/0.1.0/`, verifies the signature, and checks the bundled runtime startup protocol. It uses a persistent self-signed identity (override with a certificate name or SHA-1 using `--signing-identity`) and fails if the identity is missing or ad-hoc signing is requested. It does not notarize, publish to GitHub, or install locally. Each packaging run requires a new staging directory. The DMG uses the Retina background in `scripts/dmg/background.tiff` and the fixed icon layout in `scripts/dmg/layout.applescript`. Packaging briefly opens Finder to save the layout and requires the terminal to have permission to automate Finder.

### Message Calendar Editor Regression

After the README Debug build, run `python3 App/Tests/run-calendar-editor-regression.py` to check title, date, calendar selection, and field forwarding. Add `--preview` to open the actual grouped editor with sample calendars and no real event writes; also add `--preview-error` to simulate an initial conflict and check editing and retrying. The date row opens a calendar with numeric hour and minute menus. Creation saves through ToolService without ICS handoff or launching Calendar.

### Notification Preview

In Debug, `--test-notification` is now a compatibility alias for `--test-banner`. Both preview Asky’s own cards without sending system notifications or requesting notification permission. Release ignores both arguments.

In Debug, run `open -n build/DerivedData/Build/Products/Debug/Asky.app --args --test-banner`, or use menu bar › 预览提醒卡片, to preview Asky’s self-drawn reminder cards: top-right floating panels that never take focus. New cards line up with 8 pt gaps, then fold into a layered stack after about 4 seconds so only the front card shows; click the peeking edges to unfold and handle them one by one. Hovering pauses folding and auto-dismiss. They do not appear in Notification Center and create no calendar items.

`--drag-paste-target` uses a separate-process editor that rejects native drops, reads back the pasted result, and checks that Escape cancellation and non-input drops leave the clipboard unchanged.

`--external-drag` uses a single `AskyDragProbe` record. Set `ASKY_CLIPBOARD_TARGET_BUNDLE` to an already running app and `ASKY_CLIPBOARD_DROP_POINT=x,y` to the editor’s Quartz screen coordinates. It only inserts a draft; read back and remove that text in the destination before claiming success.
