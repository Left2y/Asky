# 模型服务商预设验证

日期：2026-10-13。

## 实现

- DeepSeek、MiniMax、GLM、Kimi、Qwen、OpenAI 预设，自动填入官方 OpenAI 兼容基础地址与默认模型，模型用下拉选项；预设地址只读。
- 获取 Key 链接、Keychain 提示；Qwen 默认北京地域，其他地域、代理与专用套餐经完全自定义配置。
- 完全自定义保留地址和模型输入；切换预设后回到自定义会恢复该页面的自定义草稿。
- 旧配置地址或模型不匹配预设时显示自定义，保留原值。不会自动升级已保存模型。
- 新地址必须提供新 Key；同地址可保留已存 Key。切换供应商清空未保存的 Key。配置编辑与保存/检查互斥，未保存草稿不展示其他配置的能力结果。

## 官方来源

本次查阅，预设只列文档中的公开模型，不宣称所有账号都有访问权限。

- [DeepSeek](https://api-docs.deepseek.com/)：`https://api.deepseek.com`，`deepseek-flash`、`deepseek-v4-pro`。
- [MiniMax](https://platform.minimaxi.com/docs/api-reference/text-openai-api)：`https://api.minimax.cn/v1`，`MiniMax-M3`、`MiniMax-M2.7`、`MiniMax-M2.5`；不将限定套餐的 Preview 设为默认。
- [GLM](https://docs.bigmodel.cn/cn/guide/develop/openai/introduction)：`https://open.bigmodel.cn/api/paas/v4`，`glm-5.3`。
- [Kimi 快速开始](https://platform.kimi.ai/docs/overview)、[模型列表](https://platform.kimi.ai/docs/models)：`https://api.moonshot.ai/v1`，`kimi-k3`、`kimi-k2.6`、`kimi-k2.7-code`。
- [Qwen](https://help.aliyun.com/zh/model-studio/compatibility-of-openai-with-dashscope)：北京通用地址 `https://dashscope.aliyuncs.com/compatible-mode/v1` 仍可使用；`qwen-plus`、`qwen3.8-max`。API Key 与地域须一致。
- [OpenAI GPT-4.1](https://developers.openai.com/api/docs/models/gpt-4.1)：保留 OpenAI 入口，GPT-4.1 系列供 Chat Completions 使用。

## 实际检查

通过：

1. `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：所有 13 个测试运行组通过，共 241 个 Swift Testing 测试。
2. `xcodegen generate`，README 中的 Debug `xcodebuild` 命令：构建成功。
3. README 中的服务商预设回归：所有预设选择与回载、旧配置保留、自定义草稿恢复、基础地址与凭据复用边界通过。
4. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --preview` 编译运行；确认新进程 PID 27948 和 `build/SettingsRegression.app/Contents/MacOS/SettingsRegression`。通过 computer-use 实际读到 OpenAI / DeepSeek 的模型下拉和只读地址，菜单包含全部预设，选择完全自定义后实际读到可编辑的地址与模型名。
5. 同一新编译的 `build/SettingsRegression.app/Contents/MacOS/SettingsRegression` 正常回归通过；人工查看 `build/settings-light-model.png`、`build/settings-dark-model.png`，布局完整无截断。
6. 两个语言的 `.strings` 经 `plutil -lint` 通过；`git diff --check` 通过。中英文 README 已同步配置步骤和预设回归命令。

未验证：没有使用用户真实 Key 向这些服务商发送付费请求，不宣称端到端模型调用已验收。此次窗口是实际 App 源码编译的独立原生回归 bundle，没有覆盖用户已安装应用。

## 文档与 Git

AGENTS.md 无变化：沿用现有 App、ToolService 与检查边界，没有新增独立模块或开发工具。

开始时已有 `SettingsView.swift`、`SettingsRegression.swift`、README 与未跟踪的 `ModelCapabilityCheck.swift` 改动；执行期间还出现另一任务的中文文案改动及验证记录。保留全部非本任务改动。模型页面与 README 的改动重叠且依赖未提交的能力检查，因此本任务未创建不完整或混合提交。构建与截图已由现有 `build/` 忽略规则覆盖。
