# 多语言全面检查

> 后续状态：本记录中的底层固定文案遗漏已在[核心文案补齐验证](2026-10-18-core-localization.md)中修复。下文保留当时的检查结果。

## 结论与范围

此前没有全部完成。此次检查覆盖 App 的 55 份 Swift 源码，以及核心包内本地化调用。原生检查范围包含全部设置页、日历编辑器、启动器与系统操作确认弹窗。

资源覆盖检查只能证明已接入本地化的静态调用完整，不能证明所有业务输出都已接入。本次仍识别到日历、备忘录等底层工具的原始错误信息含硬编码中文，见下方剩余项，因此不能宣称整个产品已完成全部多语言。

## 已修复

- 补齐模型检查 HTTP 错误与连接失败、关于页 Star 文案、记忆文件、日历编辑及保存状态、日期选择器的无障碍标签、回到底部、终端安装状态和授权失败提示。
- 修复 AI 搜索回退、打开链接、终端、单位换算结果的展示文案，以及工具耗时和代码块默认标签。
- 本地化内置操作确认的目标类型、字段、日期、时区、重复日程说明、日程重叠数量、外部应用来源与排队操作数量；保留用户输入原文。
- 本地化 AgentHost 启动、连接、协议、会话占用和工具轮数上限错误。
- 同步两个语言的键集合，消除重复的“工具调用”键，保留其原有生效值。
- 新增 `App/Tests/check-localization.py`，检查重复键、语言键集合、英文残留中文、格式参数（包括位置参数）、App 与核心包的静态本地化调用及 App SwiftUI 中文字面量。原生语言回归启动前自动执行此检查。

## 尚未全部本地化的路径

- `Packages/KulaCore/Sources/Adapters/EventKitTools.swift`：例如未授权、目标不存在、时间冲突、保存失败等 ToolError，包含固定中文及动态拼接。
- `Packages/KulaCore/Sources/Adapters/NotesTools.swift`：例如未选择授权文件夹、多文件夹消歧、目标不存在等 ToolError。
- 其他适配器、ToolService、MCP 与本地存储错误也有同类固定中文；此次未更改它们的错误契约。它们可能出现在工具错误详情中。
- 调试预览示例、AI 生成的内容、用户文件名/日历名/正文和第三方服务的原始错误不应通过对整段文本替换来翻译。

## 验证

- `python3 App/Tests/check-localization.py`：通过，扫描 134 份 Swift 源码，4 类资源表中英文键一致，无重复键、英文资源中文残留或格式参数不匹配。
- `xcodegen generate` 和 README 中的 Debug `xcodebuild` 命令：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，合计 260 个 Swift Testing 测试、51 个 suite。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-application-language-regression.py -AppleLanguages "(en)"`：通过。首次原生回归的独立弹窗 fixture 未定位到窗口；改成可见父窗口的原生 sheet 后重跑通过。
- `build/ApplicationLanguageRegression.app/Contents/MacOS/ApplicationLanguageRegression -AppleLanguages "(zh-Hans)"`：复用同一编译产物，通过。
- 两种语言均检查模型 HTTP 401/402/403/429/500 错误及 Key 脱敏、运行时错误、12 类内置确认正文、中文用户标题与内容保留，以及已有搜索与设置语言回归。
- 已查看英文关于页、模型页、权限页和中文关于页截图，新增文案显示正常。全部设置页均实际打开并保存快照；未逐页完成所有交互及错误分支的人工验收。
- 日历编辑器已实际渲染正常和保存中状态，确认弹窗已实际显示并取消。内容视图快照未完整捕获原生玻璃及 sheet 合成内容，因此这两类快照不作为视觉验收通过的依据；正文与翻译覆盖通过断言校验。
- 本次没有执行真实日历、备忘录或插件写入。

## 文档与工作区

- README: updated；在中英文开发检查中同步新增本地化覆盖检查命令。
- AGENTS.md: unchanged；现有规则已指向 README，技术边界与流程未变。
- `build/` 的既有忽略规则覆盖全部回归产物，无新增忽略规则。
- 任务开始时已有的 `docs/validation/2026-10-18-icon-preview-app.md` 保留且不提交。
