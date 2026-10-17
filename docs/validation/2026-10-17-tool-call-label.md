# 工具调用 label 展开与完整图标预览

日期：2026-10-17。

## 改动

- 错误详情展开箭头紧跟工具调用文字（4 pt 间距），移除独立 28×28 图标按钮及其背景；文字和箭头组成同一个 plain Button。
- 点击调用 label 展开或收起错误详情，保留 expanded/collapsed 可访问值与提示。无错误的文字仍可选择，展开的错误详情仍可复制。
- 日历等 App 与插件图标保留原有来源，图标槽继续为 16×16 pt；联网搜索采用 MingCute 搜索图标。
- 原生工具预览从 3 条补齐为 12 条：日历、失败插件、联网搜索、备忘录、提醒事项、联系人、信息、Chrome、快捷指令、记忆、成功插件与运行中的备忘录调用。预览断言记录数与联网搜索图标映射。
- 对话回归脚本重新创建可执行文件并签名生成的本地测试 bundle，避免反复运行旧预览后出现签名不一致。

## 已运行验证

- `xcodegen generate` 通过。
- README 中完整 Xcode Debug 构建命令通过。
- KulaCore：完整 Xcode 环境下 `swift test`，258 项通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-agent-reply-regression.py` 通过：回复、澄清持久化、取消、用时、附件历史/顺序与新对话。
- 新编译的 `AgentReplyRegression.app --tool-preview`：12 条记录断言通过；实际窗口显示各类型图标，搜索采用放大镜。
- 通过原生窗口 UI 点击 `调用 plugin_lark__help` 的文字：collapsed → expanded，错误文本可见且箭头向下；再次点击：expanded → collapsed，错误文本移除。截图确认箭头紧随文字且没有独立按钮底色。
- `git diff --check` 通过。

所有测试 bundle、截图及编译产物沿用已有 `build/` 忽略规则，不提交。
