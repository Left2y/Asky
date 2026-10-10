# README 公开展示整理

## 修改范围

- 中英文 README 改为产品介绍、能力、构建、使用、配置、项目结构及开发检查。
- 保留 macOS、Swift 与 MCP 三个有仓库依据的标签，移除排版参数、静态测试通过率和重复分类标签。
- 展示仓库已有的圆角 AppIcon，宽高均为 128；未修改应用资源。
- 移除 README 中的私人 Figma 链接、个人日历示例、个人模型验证配置和逐项开发验收表。
- 环境要求与 project.yml、SwiftPM manifests、AgentRuntime/package.json 对齐；使用子 shell 避免连续 cd 导致路径错误。

## 实际检查

- 查看引用的 AppIcon PNG：圆角白底，透明外边距。
- Python 静态检查：中英文 shell 代码块逐字一致，双方各 7 个三级章节；相对链接、图片和源码路径均存在；代码围栏闭合；仅保留 3 个标签。
- README 定向隐私检查：个人用户名、用户绝对路径、私人 Figma 链接、个人日历名称及旧验证配置均无匹配。
- 核对原生回归参数在 Swift 检查入口中的声明。
- `git diff --check -- README.md docs/validation/2026-10-10-readme-public.md`：通过。
- 仅修改文档，未重新运行构建、Swift / Node.js 测试或原生交互检查；未验证 GitHub 页面渲染。

## 边界

本次检查限于 README，不代表其他仓库文件或 Git 历史已完成隐私审计。
AGENTS.md 无需变更：项目边界、模块与既有开发检查入口未改变。
