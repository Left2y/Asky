# 指令设置品牌图标

- 设置 › 指令中的 go、chat、yt、dy、tb、jd、bl、gh 增加对应网站品牌图标，固定 20 × 20 pt，距指令文字 10 pt。图标随资产目录打包，显示时不联网。
- `>` 经 ToolService 读取当前所选终端的应用图标；所选终端未安装时显示 terminal 系统符号。
- README 中英文同步说明。AGENTS.md unchanged：没有新增开发命令、模块边界或持久指令。

## 图标来源

下载于 2026-10-11，ICO 转为 PNG 后随 App 分发：

| 指令 | 来源 |
| --- | --- |
| go | https://www.google.com/favicon.ico |
| chat | 本机官方 ChatGPT.app 的 Contents/Resources/icon-chatgpt.icns |
| yt | https://www.youtube.com/s/desktop/12d6b690/img/favicon_144x144.png |
| dy | https://www.douyin.com/favicon.ico |
| tb | https://www.taobao.com/favicon.ico |
| jd | https://m.jd.com/favicon.ico |
| bl | https://www.bilibili.com/favicon.ico |
| gh | https://github.com/favicon.ico；白色底确保深色模式可见 |

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：通过。
- `xcodegen generate`：通过。
- README 的 Debug xcodebuild 命令：通过。现有 Xcode CoreDevice/CoreSimulator 环境诊断未阻止 macOS 构建。
- 运行现有 SettingsRegression 原生回归：浅色、深色各页面、最小窗口尺寸检查通过，输出 `Settings native light/dark snapshots passed`。
- 首次使用共享回归输出路径时进程被 SIGKILL；改用 build/CommandLogosRegression.app 的隔离副本重跑通过，避免与同时进行的其他设置任务覆盖输出。临时脚本沿用现有 run-settings-regression.py，仅替换输出名称和 bundle ID。
- 检查新生成的浅色/深色 keywords 窗口截图及 Orca 捕获的原生预览窗口；九条指令图标和文字正常显示。
- 日志、临时脚本、构建和截图都在已有 build/ 忽略目录中。没有打包 Release 或安装 App。
