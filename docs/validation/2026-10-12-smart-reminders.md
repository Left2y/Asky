# 2026-10-12 后台 AI 情境建议

## 变更

- `Scheduler/SmartAdvisor.swift`：汇总日程、提醒事项与记忆，调用已配置的 OpenAI 兼容模型，校验后生成 `insight` 提醒计划。
- `ContextScheduler.reconcile` 接收 `insights`，确定性规则优先占用每日名额。
- `App/Sources/ProactiveReminders.swift`：在「后台 AI 判断」开启时接入建议、缓存与节流；设置页补充说明。

## 已运行检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：全部通过，其中 SchedulerTests 14 项（新增 SmartAdvisorTests 6 项）。
- `xcodegen generate` 后 `xcodebuild -scheme Asky -configuration Debug build`：BUILD SUCCEEDED。

## 未验证

- 未在真实模型与真实日历数据上运行，建议质量与通知实际弹出未经人工验证。
