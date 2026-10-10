# Asky Agent 身份提示词验证

- 将系统提示词中的助理名称改为 Asky，并明确历史对话中的旧名称不改变当前身份。
- 实际运行 `cd AgentRuntime && npm test`：TypeScript 编译成功，4 项测试全部通过。
- 对编译后的 `systemPrompt()` 和 `whitelistLoader().getSystemPrompt()` 执行 Node 断言：两者以“你是 Asky，”开头，提示词包含历史名称覆盖规则，检查通过。
- 未调用真实模型验证自我介绍；已运行的 Agent 进程需重新启动后加载新提示词。未打包或安装 App。
- README: unchanged；此次仅修正 Agent 身份提示词，不改变使用方式、开发命令或接口。
- AGENTS.md: unchanged；此次未改变开发流程、模块边界或持久指令。
