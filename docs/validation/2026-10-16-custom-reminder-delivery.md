# 自绘提醒投递 — 2026-10-16

## 变更

- 主动提醒从 UserNotifications 切到现有 `ReminderBannerCenter`；卡片沿用 `NSApp.applicationIconImage`，读取当前构建的黑白图标。
- 到期计划由运行中的应用定时投递，保留稍后提醒、已处理、关闭此类与原因入口。每次校验从 SQLite 恢复 scheduled / snoozed 计划，避免未变更计划或稍后提醒在重启后丢失定时器。
- 睡眠前暂停投递，启动、唤醒、时区变化及事件变化后校验；取消计划时同时撤回可见卡片与等待队列。应用退出后不交付卡片。
- ToolService 在常规启动时清除旧 `asky.reminder` / `asky.preview` 系统通知，包括待投递及已投递项；不请求通知权限。
- 权限页不再显示通知权限。Debug 的 `--test-notification` 为 `--test-banner` 的兼容别名，预览独立于真实数据、权限和 AI 启动。
- 同步中英文 README、开发指南及产品与架构中的提醒生命周期说明。

## 已执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：最终代码构建通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：250 项通过（13 个测试运行）。首轮插件运行器检查因本地缺少 AgentRuntime 依赖及编译输出失败；执行 `cd AgentRuntime && npm ci && npm run build` 后重跑通过。没有修改 AgentRuntime 源码或锁文件。
- `git diff --check`：通过。
- 检查最终差异：App 不再导入 UserNotifications 或创建系统通知；迁移清理由 ToolService 承担。构建、SwiftPM、Node 依赖和 dist 沿用已有忽略规则。

## 验证边界

- 尝试启动新构建并通过本机窗口检查工具观察 `--test-notification` 预览。进程可见，但工具返回空窗口列表；另一原生观察工具超时。因此尚未完成实际卡片、图标、按钮交互及真实到期投递的界面验收，不能将构建或现有核心测试等同于这些验收。
- 未在真实日程中创建测试事件，未修改用户提醒数据或应用程序目录中的已安装版本，未发布 Release。
- 自绘卡片不进入通知中心，也不由 macOS 专注模式管理。原生定时器与重启恢复路径仍需真实提醒场景验收。

## 维护门槛

- README: updated — 同步中英文自绘卡片、权限与退出后的投递边界。
- AGENTS.md: unchanged — 延续既有 App / ToolService 边界及构建测试命令，无新增独立子项目或通用开发规则。
