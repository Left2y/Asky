# 上下文压缩 loading

- Pi SDK `compaction_start` / `compaction_end` 通过现有 taskState 通道发送 `compacting` / `running`。压缩状态不是终态，保留停止生成与任务计时。
- 对话原有状态位置显示小号原生 ProgressView、8 pt 间距和“正在压缩上下文…”；复用 14 pt 正文字号、弱文字色，英文为“Compacting context…”。
- README 中英文与运行时文档同步；AGENTS.md 无需改变，模块边界与命令未变。

## 实际检查

- `xcodegen generate` 通过；README 的 Xcode Debug 构建命令通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：267 项通过。
- `cd AgentRuntime && npm test`：10 项通过。新增测试使用真实 Pi SDK 和本地模拟 OpenAI 接口，先建立历史，再返回 120003 tokens 的 usage，触发实际摘要请求，确认 `compacting → running → completed`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-agent-reply-regression.py --compaction-preview`：浅色、深色实际窗口截图与恢复、取消断言通过。窗口截图使用 window ID，避免并行窗口遮挡。
- 视觉检查为注入任务事件的真实界面；SDK 测试为本地模拟服务，未用付费模型跑超长对话。
- 构建、截图与日志沿用已有 `build/`、`AgentRuntime/dist/` 忽略规则，不提交。
