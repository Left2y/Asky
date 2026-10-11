# 飞书官方插件验证 — 2026-10-11

## 实现

独立仓库 `Niall-Young/asky-plugin-lark`，插件 ID `lark`，API v1；提供 help、query、execute，配置本机 CLI 路径和 user/bot 身份。Asky 设置增加飞书官方入口，精确来源认定与 Orca 使用相同规则。无 npm 运行依赖。

## 实际检查

- 插件 `npm test`：6 项模拟测试通过，包括写入隔离、身份覆盖拦截、风险未知拒绝、防重放、超时与 CLI exit 10。
- 本机 `lark-cli`：具体命令 help、内置 skills list、calendar.calendars.list schema 返回成功。
- 随项目构建的 plugin-runner，通过真实 RPC 执行 skills list、schema 和 auth status --verify，均收到结果；未记录凭证或用户响应正文。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：核心包各测试套件通过。
- `xcodegen generate` 与 README 的 Debug `xcodebuild`：通过。
- `python3 App/Tests/run-settings-regression.py --plugins-only`：中文 light/dark 原生截图生成通过，已查看浅色截图并确认飞书入口和安装按钮。此为真实 SwiftUI 设置视图回归程序，不是用户主应用安装与 AI 端到端验收。

## 限制

未执行真实飞书写入。通用 CLI 写入没有自动资源验证，readback 返回 null，执行记录待核实；模型需另外 query 回读对象，查询不自动清除历史 pendingVerification 标记。CLI 安装/登录、凭证管理、更新与 raw api 不由插件提供。未打包、安装或发布 Asky 应用。
