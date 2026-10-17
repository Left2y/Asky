# 对话工作时长与完成时间

## 变更

- 本轮工作时长移至回复上方，使用与失败工具详情一致的箭头；点击展开工具调用数量及列表，工具失败详情继续独立展开。
- 执行中默认隐藏调用链，完成时收起；正文保持可见。
- 回复底部左侧显示复制按钮及完成时间。不足 60 秒显示“刚刚”，不足 1 小时显示分钟前，不足 24 小时显示小时前，不足 72 小时显示天前；之后显示 `yyyy-MM-dd HH:mm:ss`。悬停可查看完整时间，标签随时钟刷新。
- 当前会话按任务 ID 分组。历史仍沿用原有持久化结构：恢复消息写入时间作为时间标签；工具链与工作时长仍仅在当前会话内存中保留。

## 实际执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-agent-reply-regression.py --tool-preview`：编译并启动实际窗口；同一回归产物不带参数运行，全部断言通过，覆盖澄清回复、完成时间、取消、历史附件、新对话，以及 59/60 秒、3599/3600 秒、24/72 小时时间边界和时钟回拨。
- 使用 computer-use 技能检查独立测试窗口（`pid:82909`）：初始为 collapsed，工具链不可见，工作时长在正文上方，复制与“刚刚”在左下；点击后为 expanded，显示 13 次工具调用，再点击失败项展开错误信息。
- `git diff --check`：通过。

## 范围

窗口使用临时本地数据与模拟工具事件，无真实工具执行。自动完成收起由视图监听运行状态实现；本次窗口检查覆盖完成后默认收起与手动展开，未执行真实模型请求。
