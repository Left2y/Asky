# 开源协议验证（2026-10-11）

本次仅添加 MIT 协议、README 授权说明和 npm 许可证元数据，未修改运行时代码。

## 已运行检查

- 使用 Python 获取 Choose a License 上游 MIT 模板，替换年份和版权署名后逐字比较根目录 `LICENSE`：通过。
- 解析 `AgentRuntime/package.json` 与 `package-lock.json`，确认 manifest 与 lockfile 根包的 `license` 均为 `MIT`：通过。
- 检查 README 中英文授权说明、三个 LICENSE 链接目标及双语导航锚点：通过。
- `git diff --check`：通过。

GitHub licenses API 首次请求遇到 HTTP 403（rate limit exceeded），随后改用 Choose a License 上游原始模板完成比较。

## 范围

版权署名依据仓库作者身份采用 `Niall-Young`，年份为 2026。第三方依赖仍遵循各自许可证。本次未执行 Swift / Node.js 测试或 App 构建，因为未修改代码或构建命令；未进行完整第三方授权与资源来源审计。
