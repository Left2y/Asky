# 更新检查的 GitHub API 限流恢复

Date: 2026-10-11.

## 原因与变更

- 实际请求 `https://api.github.com/repos/Niall-Young/Asky/releases/latest` 返回 HTTP 403，`x-ratelimit-limit: 60`、`x-ratelimit-remaining: 0`；响应正文明确为 API rate limit exceeded。未在记录中保留出口 IP。
- ToolService 在 API 返回 403/429 时读取公开 `/releases/latest`，使用重定向后的 tag 页及其 `/releases/expanded_assets/` 资产列表查找更新。只接受该仓库、该 tag 的 GitHub HTTPS 下载链接，排除源代码归档及外部链接。
- 匹配 ZIP 与同名 `.sha256`，保留原有数字版本比较与安装校验流程。网页读取和解析失败仍报告错误，不误报“已是最新版本”。
- 进程内记住 API reset / retry-after 冷却时间，冷却期间直接使用网页；网页及安装资产请求不发送 API 专用 Accept 头。
- README 中英文同步备用查询行为。AGENTS.md 的现有模块边界、开发命令与作用域仍适用，无新增持久指令。

## 已执行检查

```sh
curl -sS -H 'Accept: application/vnd.github+json' -H 'User-Agent: Asky-Updater' https://api.github.com/repos/Niall-Young/Asky/releases/latest
curl -sSL https://github.com/Niall-Young/Asky/releases/latest
curl -sSL https://github.com/Niall-Young/Asky/releases/expanded_assets/v0.0.9
(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build
git diff --check
```

- 核心包完整测试通过；更新回归覆盖 403 与 429 自动恢复、重复检查只请求 API 一次、404 保持错误、ZIP / 校验文件匹配及源代码归档和无关链接排除。
- Debug App 构建通过。
- 临时 Swift 可执行探针直接编译实际 `AppUpdate.swift`（仅提供空的 ToolService 类型），调用 `AppReleaseLookup.shared.latest()` 与公开 `ToolService.checkForAppUpdate()`，使用真实 URLSession / 当前网络。成功返回 0.0.9、`Asky-0.0.9-macos-arm64.zip` 与同名 `.sha256`。这验证了实际网络恢复链路；探针的 Bundle 版本默认为 0，公开方法因此返回可更新版本。
- 构建输出复用现有 `.gitignore` 中的 `build/` 与 `Packages/KulaCore/.build/` 规则。

## 验证边界

- 未替换已安装的 Asky，未打包或发布；现有安装版需要包含此次改动的新构建才能获得此修复。
- 未在真实设置窗口点击按钮，也未执行安装替换。此项只修改 ToolService 更新查询逻辑，界面与安装流程未修改。
- 网页备用路径依赖 GitHub Release 页面结构；结构变化或网页同样不可达时，检查会报告错误。
