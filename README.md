# KulaHere

[中文](#中文) | [English](#english)

<a id="中文"></a>

## 中文

### 项目简介

KulaHere 是一个规划中的 macOS 原生效率入口，采用 SwiftUI 与 AppKit，以快捷搜索和确定性工具为基础，通过 AI、本地记忆和情境提醒增强日常工作流。

当前仓库处于产品定义阶段，包含框架与 PRD，尚无应用源码、可运行程序或构建配置。首版目标是完整自用版，分阶段实现。

### 核心能力

V1 规划包含三个层次：

- 桌面入口：应用、文件、Chrome 标签页、命令、小工具与剪贴板历史。
- AI 增强：自然语言对话、截图理解、系统工具及 Messages 草稿交接。
- 个人上下文：本地记忆与有依据的少量情境提醒。

用户自带模型 API Key，必要上下文可以按授权发送给配置的模型。独立本地 MCP 与应用共用系统工具，外部接入单独授权。短信最终由用户在 Messages 中发送。

### 文档

- [产品框架与架构大纲](docs/framework.md)：模块、数据流、进程和接口边界。
- [V1 产品需求文档](docs/PRD.md)：已确认范围、用户流程、分阶段交付与验收标准。

### 开发与验证

目前没有可执行的安装、运行、构建或测试命令。实现开始后，先完成能力与权限验证，再按 PRD 的 M1 至 M4 顺序交付；实际命令随项目配置建立后补充。

<a id="english"></a>

## English

### Overview

KulaHere is a planned native macOS productivity launcher built with SwiftUI and AppKit. Fast search and deterministic tools form its foundation, while AI, local memory, and contextual reminders enhance everyday workflows.

The repository is currently in the product definition stage. It contains a framework outline and PRD, with no application source, runnable program, or build configuration. V1 targets a complete personal-use release delivered in stages.

### Features

V1 is planned around three layers:

- Desktop launcher: applications, files, Chrome tabs, commands, utilities, and clipboard history.
- AI assistance: natural-language conversations, screenshot understanding, system tools, and draft handoff to Messages.
- Personal context: local memory and a small number of evidence-based contextual reminders.

Users supply their own model API key. Necessary context may be sent to the configured model with authorization. A standalone local MCP shares system tools with the application, with separate authorization for external access. Users send messages themselves in Messages.

### Documentation

- [Product framework and architecture outline](docs/framework.md): modules, data flow, process boundaries, and interfaces.
- [V1 product requirements](docs/PRD.md): confirmed scope, user flows, staged delivery, and acceptance criteria.

### Development and Verification

There are no runnable installation, startup, build, or test commands yet. Implementation starts with capability and permission validation, followed by stages M1 through M4 in the PRD. Actual commands will be documented when project configuration exists.
