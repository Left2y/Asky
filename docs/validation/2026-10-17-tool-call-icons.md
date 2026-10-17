# AI 工具调用图标尺寸与错误状态

日期：2026-10-17。

- 工具调用行的图标槽由 20×20 改为 16×16 pt，覆盖运行中加载指示、错误、插件、数据来源 App 与通用图标。
- 日历、提醒事项等来源仍使用对应真实 App 图标；插件仍可使用自己的图标，通用回退保持 MingCute。
- 工具失败由圆形叉号改为 MingCute `warning`（圆形感叹号），普通对话错误也使用同一 16×16 图标。
- 展开的错误详情左侧缩进同步为 24 pt（16 图标 + 8 图文间距），与工具文字对齐。

已运行：`xcodegen generate`、README 的完整 Xcode Debug 构建均通过；KulaCore 在 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` 下执行 `swift test`，258 项通过。

对话回归程序已编译。首次启动因复用的本地预览 bundle 签名失效被 SIGKILL；对 `build/AgentReplyRegression.app` 重新执行本地 ad-hoc 签名后，直接运行回归程序通过回复、附件历史恢复与新对话检查。

使用同一新编译程序的 `--tool-preview` 实际查看窗口：日历成功行使用真实日历 App 图标，失败行显示圆形感叹号，运行中行显示加载指示，三者统一占 16×16 pt。

`git diff --check` 通过。

构建与回归产物沿用已有 `build/` 忽略规则，不提交。
