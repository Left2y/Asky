# 备忘录自动连接与文件夹选择

日期：2026-10-12。

## 变更

数据来源设置以「连接备忘录」替代账户、文件夹手填。通过 ToolService 的原生配置工具读取账户及文件夹名称、标识，递归发现子文件夹，按账户显示勾选列表；选择自动持久化。旧配置按账户与名称匹配，连接后补充标识；缺失的已选文件夹仍可取消。加载中防止重复请求，错误提供重试及自动化权限设置入口。

发现工具不读取正文，不向 AI 或 MCP 暴露。内容工具继续受来源开关与文件夹范围限制。

## 已执行检查

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。新增旧配置解码、标识引用、范围为空的拒绝行为、AI/MCP 发现工具隔离检查。
- `python3 App/Tests/run-settings-regression.py`：通过。新增文件夹标识迁移与取消选择的设置回读检查，使用独立临时数据，不修改用户范围。
- 中英文 `.strings` 的 `plutil -lint`：通过。
- 新构建 Debug 应用真实窗口：进入数据来源，确认手填输入框已移除且连接按钮可用；点击连接后，成功显示本机 `iCloud → Notes` 文件夹，按钮变为「刷新文件夹」。截图视觉检查通过，未自动勾选任何文件夹。

## 验收边界

本机已经允许 Asky 自动化访问 Notes；首次系统授权弹窗及拒绝后恢复入口未在真实 TCC 状态下验证。当前账户只返回一个顶层文件夹，子文件夹递归发现及以标识访问子文件夹尚未完成真实账户验收。未读取或写入任何备忘录正文。

README：已同步中英文配置流程。AGENTS.md：unchanged；既有 App/Core 边界、构建与测试命令仍适用。
