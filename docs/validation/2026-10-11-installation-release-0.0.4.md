# Asky 0.0.4 安装流程与发布验证

## 实现与已执行检查

- 发布构建在 AppModel、快捷键、剪贴板和权限界面启动之前检查运行位置；开发构建保留 KHSourceRoot，不触发安装提示。
- DMG / Downloads / AppTranslocation 启动时使用原生 NSAlert 提示安装；经用户选择后，ToolService 将完整应用复制到 Applications，校验签名，再等待原进程退出后重新打开。
- 已安装同 bundle identifier 的应用时提供打开已有版本；不会覆盖既有应用。无写入权限时提供 Finder 安装说明。临时复制目录失败后清理，下载源保留。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --package-path MCPBridge`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：172 项通过。新增测试覆盖系统与用户 Applications、DMG / Downloads / Translocation、已有目标保护、含空格路径的真实签名应用复制，以及签名损坏后的临时文件清理。
- `cd AgentRuntime && npm ci && npm test`：4 项通过。
- `xcodegen generate` 与 Release arm64 xcodebuild（`build/Release004DerivedData`）：通过。
- 实际打开移除 KHSourceRoot 后的原生构建，检查截图及 accessibility tree：显示“安装 Asky”“安装并重新打开”“退出”，文字完整。随后观察到 Applications 中的副本与新进程，源进程退出；预览构建尚未包含 runtime，因此将在打包后用完整发布产物替换该预览副本。
- 官方 Node 22.23.3 arm64 下载清单与本地 archive SHA-256、解压后的 Node 可执行文件逐字节比对：通过。

## 发布流程

新增可重复使用的 `scripts/package-release.py`，只接受已提交的干净源码工作区，生成 DMG、ZIP 与两份 SHA-256 校验文件；DMG 内提供 Asky.app 与 Applications 符号链接，ZIP 保留给现有应用更新器。

README 中英文已同步 DMG 安装方式、首次启动提示和打包入口。AGENTS.md 已增加该发布打包入口说明。

## 限制

本机没有 Developer ID 签名身份，使用 ad-hoc 签名，未经 Apple 公证。真实 Gatekeeper 首次下载授权、辅助功能授予、模型请求和完整旧版更新安装不记为通过。

构建、截图、Node 下载、生产依赖和发布产物位于现有忽略的 build/；复用忽略规则，不提交这些产物。
