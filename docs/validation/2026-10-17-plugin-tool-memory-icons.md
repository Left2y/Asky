# 插件统一 tool 与记忆 brain 图标

日期：2026-10-17。

## 最终改动

- 所有插件（包括 Orca、飞书）统一采用 MingCute `tool` 图标，工具调用行使用 16×16 pt，插件设置沿用 36 pt 图标槽。
- 去除插件品牌/自定义图像加载路径；不再出现 Orca 的 macOS 图标底板和边框。
- 记忆调用使用 MingCute `brain`，日历等 App 图标保留。工具失败仍使用圆形 warning，加载状态仍使用原生进度指示。
- 工具预览包含 13 条记录，飞书同时有成功与失败示例；断言所有插件映射到 tool，记忆映射到 brain。
- 对话回归脚本支持 `ASKY_DERIVED_DATA`，以独立构建产物和测试 bundle 进行并行验证，避免覆盖正在使用的测试程序。

## 已执行检查

- `xcodegen generate` 通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/IconValidationDerivedData build` 通过。
- KulaCore：完整 Xcode 环境 `swift test`，258 项通过。
- 使用 `ASKY_DERIVED_DATA=/Users/niallyoung/orca/Asky/build/IconValidationDerivedData` 执行 `python3 App/Tests/run-agent-reply-regression.py` 通过。
- 使用相同独立构建目录执行 `python3 App/Tests/run-settings-regression.py --plugins-only` 通过，生成深浅色插件设置截图。
- 实际查看独立构建的对话预览窗口：Orca 和飞书成功调用使用同一 tool，记忆为 brain，图标槽为 16×16 pt。
- 实际查看本次浅色插件设置截图：Orca、飞书使用同一 tool，无品牌底板。
- `git diff --check` 通过。

首次共享目录的设置回归因并行构建修改 LocalStore.o 失败；独立目录的首次对话回归又因其他任务修改 AgentView.swift 失败。代码稳定后重跑上述检查均通过。其他任务的展开动画、按下颜色和回到底部改动保留，并由其所属任务分别提交。

所有测试 bundle、截图及构建产物沿用已有 `build/` 忽略规则，不提交。
