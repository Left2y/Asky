# AgentRuntime

这是可独立构建与测试的 TypeScript / Node.js Pi 宿主。负责模型、会话和工具编排，以及由 ToolService 启动的通用插件执行协议，通过 stdio JSONL v2 与原生应用通信；接口和生命周期以[运行时文档](../docs/agent-runtime.md)为准。
