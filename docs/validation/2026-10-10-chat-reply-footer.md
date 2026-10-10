# 澄清重复回复与耗时底部行

日期：2026-10-10。

## 修复

- `AgentModel` 原先收到 `clarification` 后追加问题，但没有清空已有流式文字；`finishTask` 又追加这段文字，导致一次澄清有两个回复和两个复制按钮。现在问题收束流式文字，并通过 ConversationStore 保存，重新打开历史仍能读到问题。
- 显式提交开始记录任务开始时间；运行中每秒更新左下角 `Work for …s`。完成或停止后将耗时放在当前任务最后一条回复的底部，与右侧复制按钮共用一行。
- 耗时属于当前加载消息的展示状态；重新加载历史不恢复耗时。原有历史中的重复消息不做数据迁移或删除。

## 实际运行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：133 tests / 27 suites 通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `python3 App/Tests/run-agent-reply-regression.py`：通过。回归使用真实 AgentModel、临时数据库及 Debug 链接产物，不调用外部模型、不读取用户对话。
- `python3 App/Tests/run-agent-reply-regression.py --preview` 打开独立原生测试窗口，使用主应用的 Assets.car。经 `orca computer get-app-state` 及截图确认：澄清只有一段正文、一个复制按钮，左下角显示 `Work for 13s`，复制按钮位于右侧。

覆盖：流式文字后澄清、澄清问题持久化与历史重开、完整消息替换增量、停止时保留部分回复、完成时耗时冻结及运行状态清除。真实模型调用未在本次验证中执行。

测试二进制、测试 app、编译产物均由现有 `build/` 忽略规则覆盖。
