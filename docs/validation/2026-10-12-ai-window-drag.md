# AI 窗口顶部拖动

## 修复

- `AgentView.header` 使用矩形命中区域和原生 `WindowDragGesture`，明确将顶部导航背景与标题区域作为拖窗入口。
- `allowsWindowActivationEvents()` 允许从非活动窗口开始拖动。置顶仍由既有窗口 level 控制；布局和按钮尺寸不变。
- 手势使用普通优先级，保留子视图控件的事件优先级。原生 API 依据：[Apple WindowDragGesture](https://developer.apple.com/documentation/swiftui/windowdraggesture)。Xcode SDK 声明支持 macOS 15+。

## 已执行检查

- `swift test` 初次使用当前 Command Line Tools，因缺少 `Testing` 模块失败。
- 在 `Packages/KulaCore` 执行 `env -u SDKROOT DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，共 226 项测试。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/AIDragDerivedData build`：通过。
- 新构建启动后确认进程路径为 `build/AIDragDerivedData/Build/Products/Debug/Asky.app/Contents/MacOS/Asky`（PID 41286）。

## 实机验收限制

尝试通过原生界面自动化与快捷键打开新进程的 AI 窗口，未成功。期间再次出现其他开发构建和 `/Applications/Asky.app` 的并行进程；快捷键与按应用名选择均无法可靠定位此次构建。按新 PID 读取报告无可见窗口。

不能将这些尝试记为拖动通过。待确认：未置顶和置顶时拖动标题与顶部留白、非活动窗口直接拖动、历史搜索文本选择，以及历史／新对话／置顶／关闭按钮点击。macOS 15 实机行为也未验证。

## 工作区与文档

基线已有设置、剪贴板、搜索及 README／PRD 改动；此次仅提交 `AgentView.swift` 与本记录。构建目录沿用现有 `build/` 忽略规则。

README: unchanged — 恢复既有窗口移动行为的小修复，不改变使用入口、命令或配置。

AGENTS.md: unchanged — 现有 App 指令覆盖此次原生界面修复，未引入新的工程或模块约束。
