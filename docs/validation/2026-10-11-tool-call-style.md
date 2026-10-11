# 工具调用状态样式验证

## 修改

- 左侧同一位置在调用中显示 spinner、成功后显示来源图标、失败后显示 `xmark.circle`；插件使用清单图标或对应本机应用图标，缺省为插件占位图标。
- 标题末尾不显示成功 / 失败图标，不把状态文字或错误消息拼进调用标题。
- 工具行统一使用原来的弱化文字颜色。错误详情默认折叠，右侧原生按钮展开 / 收起，可选择复制错误文字。
- 等待确认、待核实、取消等其他状态继续显示对应文字；权限管理入口保留。

## 实际执行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 `Packages/KulaCore`）：通过。
- `xcodegen generate`：通过。
- README 的 Debug `xcodebuild` 命令：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-agent-reply-regression.py --tool-preview`：成功编译并打开真实原生窗口；预览断言验证成功标题无完成文案、失败标题无错误详情、错误内容独立保存、插件 ID 解析正确。
- 同一构建产物不带预览参数运行：回复、附件恢复、新对话回归通过。
- 通过 computer-use 检查新启动窗口：成功日历图标、失败圈叉、调用中 spinner 可见；错误初始折叠，点击后展开，再次点击可收起；无红色错误文字。
- `git diff --check`：通过。

首次预览编译遇到 SDK 版本不一致，显式指定 Xcode 工具链后通过。视觉检查使用临时数据的真实 AgentWindowController，不调用真实飞书 CLI，也不验证截图中 CLI 命令失败的原因。

## 文档维护

README: updated — 中英文同步工具调用图标与错误折叠行为。

AGENTS.md: unchanged — 本次未改变开发命令、独立子项目或系统服务边界。
