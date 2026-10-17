# 剪贴板复制提示自动消失

日期：2026-10-17。

- 复制状态 toast 在显示 2 秒后自动清除，卡片与列表共用。
- 连续复制相同内容或收到新的状态时取消旧计时并重新计时。
- 关闭剪贴板窗口时取消待执行任务并清空状态，避免旧计时影响下次打开。

## 实际验证

- `xcodegen generate`：通过。
- README 中 Debug `xcodebuild`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：已运行；AgentHostTests 中 `RealRuntimeIntegrationTests.unreachableModelFailsAndProcessIsGone` 仍因缺少 `.running` 与运行 PID 失败，其余套件通过，与上次列表复制验证结果一致。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts`：通过。实际窗口验证复制后 toast 可见、约 1 秒后再次复制会重新计时、再次复制 1 秒后仍可见、再等 1.2 秒后状态清空且 toast 隐藏，同时列表保持打开。首次运行在计时检查之前因选中项为空中止；回归改为取消窗口输入焦点并清空查询，隔离并发桌面输入。

README 与 AGENTS.md 无需修改：本次恢复已有复制提示的临时显示行为，命令、使用方式与架构边界未变。构建和回归产物沿用已忽略的 `build/`，未新增忽略规则。
