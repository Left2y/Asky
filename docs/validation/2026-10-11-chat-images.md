# AI Markdown 图片与主题验证

日期：2026-10-11。

## 实现

实时及历史助手消息共用 ChatMarkdownView，支持 HTTP／HTTPS 独立图片与行内图片。独立图片等比例缩放，最大展示高度 420 pt，12 pt 圆角与语义边框；显示加载状态，失败可重试。行内图片限制到 20 pt 高度。图片内容保留原始颜色，容器和状态随应用外观变化。

表格使用主题边框、交替行背景及 14 pt 正文，表头 Medium，横向滚动容器；引用、分隔线、链接与行内代码也使用语义主题。正文 14/400、标题 16/500 和原有代码块 8 pt 圆角保持，代码块等宽并可横向滚动。

图片网络读取位于 KulaCore 的 ToolService 模块 ChatImageService；仅接受无 URL 用户凭据的 HTTP／HTTPS 地址。使用无共享 Cookie、凭据和磁盘缓存的临时会话，单次下载限制 10 MiB、请求超时 20 秒、资源超时 30 秒，图片缩略到最长边 1600 像素；内存缓存上限 32 MiB。Markdown 不读取本地文件图片。远程站点可看到连接信息与图片 URL 参数，README 和 PRIVACY.md 已同步。

## 已执行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：全部通过，包括新增 URL 范围、无效图片数据和 3200×1600 下采样至 1600×800 的回归测试。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：成功。Xcode 的 CoreSimulator／CoreDevice 环境警告未阻断 macOS 构建。
- 编译实际 ChatMarkdownView 与 Debug 包产物，启动浅色／深色两个原生预览窗口，通过 computer-use 截图检查标题、正文、引用、表格、代码、独立图片、行内图片和失败状态。使用临时本机 HTTP 图片服务，不调用模型、不写真实会话库。
- HTTP 探针：真实下载、原生图片解码成功；404、非图片数据和声明超过 10 MiB 的响应均被拒绝。点击预览窗口的重试按钮后，服务日志确认新增 GET 请求；目标仍返回 404，界面正确继续显示失败。
- `git diff --check`：通过。

## 范围与维护

本次检查真实渲染器的原生窗口，未通过模型生成图片回复验证完整对话流程；离线恢复、超时、重定向、缓存压力和超宽表格滚动尚未专项实测。图片为静态预览，不承诺 SVG、动画播放或本地文件支持。

README 已同步中英文功能说明。AGENTS.md: unchanged；沿用既有 App／ToolService 边界与构建测试入口，没有新增独立子项目或持久开发规则。临时探针在系统临时目录，预览二进制及应用包沿用已有 `build/` 忽略规则。
