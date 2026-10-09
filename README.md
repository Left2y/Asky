# KulaHere

[中文](#中文) | [English](#english)

<a id="中文"></a>

## 中文

### 项目简介

KulaHere 是一个规划中的 macOS 原生效率入口，采用 SwiftUI 与 AppKit，以快捷搜索和确定性工具为基础，通过 AI、本地记忆和情境提醒增强日常工作流。

当前仓库处于产品定义阶段，包含 PRD、框架和技术专题，尚无应用源码、可运行程序或构建配置。首版目标是完整自用版，分阶段实现。

### 核心能力

V1 规划包含三个层次：

- 桌面入口：应用、文件、Chrome 标签页、命令、小工具与剪贴板历史。
- AI 增强：自然语言对话、截图理解、系统工具及 Messages 草稿交接。
- 个人上下文：本地记忆与有依据的少量情境提醒。

用户自带模型 API Key，首版优先 OpenAI-compatible Chat Completions，必要上下文按授权外发。Pi SDK 是待原型验证的 Agent 方案：原生入口常驻，明确 AI 请求才启动辅助进程，空闲后退出；后台模型唤醒默认关闭。界面使用用户 Figma 变量与 Styles 和原生 Liquid Glass，资源占用通过有界加载与生命周期管理控制。

独立本地 MCP 与应用共用系统工具，外部接入单独授权，不依赖 Pi。短信最终由用户在 Messages 中发送。

### 文档

- [文档索引](docs/README.md)：阅读顺序、权威内容与设计状态。
- [V1 产品需求文档](docs/PRD.md)：已确认范围、用户流程、默认行为与验收。
- [产品框架与架构大纲](docs/framework.md)：技术栈、模块、数据流、进程和接口边界。
- [原生界面与设计系统](docs/design-system.md)：Figma 数据、控件映射与液态玻璃。
- [Agent Runtime](docs/agent-runtime.md)：Pi、扩展、模型与按需进程。
- [原生工具与 MCP](docs/native-tools-and-mcp.md)：系统适配器、权限、确认与回读。
- [数据、记忆与提醒](docs/data-and-memory.md)：持久化、来源、清理与后台调度。
- [资源生命周期与性能](docs/resource-lifecycle.md)：缓存预算、分页、释放与测量。
- [实施与验证](docs/implementation-and-validation.md)：M0–M4 门槛、风险与验收映射。

### 开发与验证

目前没有可执行的安装、运行、构建或测试命令。实现开始后，先完成能力与权限验证，再按 PRD 的 M1 至 M4 顺序交付；实际命令随项目配置建立后补充。

<a id="english"></a>

## English

### Overview

KulaHere is a planned native macOS productivity launcher built with SwiftUI and AppKit. Fast search and deterministic tools form its foundation, while AI, local memory, and contextual reminders enhance everyday workflows.

The repository is currently in the product definition stage. It contains a PRD, architecture outline, and technical specifications, with no application source, runnable program, or build configuration. V1 targets a complete personal-use release delivered in stages.

### Features

V1 is planned around three layers:

- Desktop launcher: applications, files, Chrome tabs, commands, utilities, and clipboard history.
- AI assistance: natural-language conversations, screenshot understanding, system tools, and draft handoff to Messages.
- Personal context: local memory and a small number of evidence-based contextual reminders.

Users supply their own model API key, with OpenAI-compatible Chat Completions prioritized for V1. Necessary context is sent only with authorization. Pi SDK is the proposed Agent runtime pending prototype validation: the native launcher stays running, while an explicit AI request starts a helper that exits after idle time. Background model wakeups are disabled by default. The interface uses the user's Figma variables and Styles with native Liquid Glass; bounded loading and resource lifecycles govern memory use.

A standalone local MCP shares native tools with the application, requires separate external authorization, and does not depend on Pi. Users send messages themselves in Messages.

### Documentation

- [Documentation index](docs/README.md): reading order, authoritative specifications, and design status.
- [V1 product requirements](docs/PRD.md): confirmed scope, user flows, defaults, and acceptance criteria.
- [Product framework and architecture](docs/framework.md): technology choices, modules, data flow, processes, and interfaces.
- [Native interface and design system](docs/design-system.md): Figma data, native controls, and Liquid Glass.
- [Agent runtime](docs/agent-runtime.md): Pi, extensions, models, and on-demand processes.
- [Native tools and MCP](docs/native-tools-and-mcp.md): adapters, permissions, confirmations, and readback.
- [Data, memory, and reminders](docs/data-and-memory.md): persistence, provenance, cleanup, and background scheduling.
- [Resource lifecycles and performance](docs/resource-lifecycle.md): cache budgets, pagination, release, and measurement.
- [Implementation and validation](docs/implementation-and-validation.md): M0–M4 gates, risks, and acceptance mapping.

### Development and Verification

There are no runnable installation, startup, build, or test commands yet. Implementation starts with capability and permission validation, followed by stages M1 through M4 in the PRD. Actual commands will be documented when project configuration exists.
