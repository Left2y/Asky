# 应用内弹窗统一与可读确认文案

日期：2026-10-12。

## 覆盖范围

应用自有弹窗统一由 ToolService 的 `AppDialog` 创建 NSAlert，并加载 Asky 图标。覆盖工具写入确认、插件安装信任确认、应用更新、首次安装与安装失败、图片下载失败、本地数据打开失败、通知测试失败、提醒依据详情，以及 Chrome 文件夹读取失败。

SwiftUI 的插件安装 alert、应用更新 confirmationDialog 与图片下载错误 alert 改经 `appDialog` modifier 呈现同一原生组件。系统权限申请、系统文件选择器、插件配置编辑 sheet、安装进度窗口与普通产品窗口不属于操作确认弹窗，保持各自用途与布局。

确认页默认显示可读的动作、目标和变更。原始工具名移至默认收起的“操作详情”；插件完整参数保留在可展开、可选择、可滚动的详情中。外部 MCP 请求仍标明来源。插件 adapter 不再将供 AI 阅读的工具说明当作确认正文：已识别的 CLI 路由显示创建、修改、删除、发送等动作，并提取实际请求中的标题、正文等关键文本；未知路由使用通用插件操作标题，不猜测目标或动作。结构化字符串留在详情中。

ConfirmationRequest 新增可选 title/details，旧载荷仍可解码；授权、参数摘要绑定、确认结果及 ToolService 写入执行策略不变。

## 已执行

- `xcodegen generate` 通过。
- README 的 Debug xcodebuild 命令与同工程 Release 构建均通过。
- `Packages/KulaCore` 中 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 通过；新增测试验证可读插件预览、完整参数保留、未知命令不猜测，以及旧确认载荷解码。
- 中英文 Localizable.strings 通过 `plutil -lint`；`git diff --check` 通过。
- 全项目 Swift 扫描确认：NSAlert 的创建仅在 AppDialog 中；App 不再使用 SwiftUI `.alert` 或 `.confirmationDialog`。
- 新 Debug 主应用 `--test-confirmations` 实际窗口通过 Orca 检查：工具标题已显示“修改日程？”、“准备信息草稿？”等文案。飞书预览正文显示标题“示例”，默认隐藏工具参数；点击操作详情后读回展开状态与完整参数，并检查截图中内容与按钮均完整显示。
- 主应用 Debug 预览还运行插件安装、更新和图片错误提示的模拟弹窗；未通过这些预览执行真实业务操作。
- 用最终 AppDialogModifier 源码和 Debug ToolService 编译本地 SwiftUI 探针；可访问性树显示安装确认的标题、正文与安装/取消按钮。点击取消后进程输出 `modifier-preview response=1` 并退出，验证取消不会被当作首按钮批准；工具在退出后无法再捕获窗口，以返回记录为准。此探针没有安装动作。
- 新 Release 构建与原已安装版本的 AgentRuntime、Node 组合为本地应用，保留本机 0.0.17 版本标记，重新签名并通过 `codesign --verify --deep --strict`。备份原安装后替换 `/Applications/Asky.app` 并启动；安装后可执行文件摘要与准备好的本地应用一致。这是本机验证构建，没有重新发布 GitHub Release 或覆盖发布资产。

## 验证边界

未执行真实插件安装、应用更新、飞书写入或其他系统写入。模拟请求与组件检查不等于这些外部动作的验收；未知插件命令的具体参数需在操作详情中核对。

本地应用备份、预览产物位于 `build/validation/dialog-unification/`，由已有 `build/` 规则忽略。

README: updated — 中英文同步弹窗行为与预览范围。AGENTS.md: unchanged — 既有 App/ToolService 边界与验证规则仍适用。
