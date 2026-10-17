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

## 展开动效修正

用户反馈工具列表看起来从正文上方滑入。原因是使用了 `.move(edge: .top)` 插入过渡；修正为保留内容布局，以顶部为锚点动画展开容器高度，并裁剪隐藏部分及淡入淡出，不再平移列表。折叠时不保留额外段落间距，隐藏内容不接收点击或辅助功能焦点。

重新执行 `xcodegen generate`、Debug `xcodebuild`、KulaCore `swift test` 均通过。README 所述行为与开发命令不变；AGENTS 指令与模块边界不变。

修正后的聊天回归产物全部断言通过；实际窗口 `pid:87482` 初始 collapsed，点击后 expanded，截图捕获到裁剪区域内逐渐显示的列表，列表首行保持原位；再次点击恢复 collapsed，调用列表从辅助功能树移除，正文保留。

## 调用次数与零调用修正

移除工具调用次数文案及对应本地化项。零调用时工作时长为普通文字，不渲染按钮和箭头；有调用时保持展开详情交互。

重新执行 XcodeGen、Debug 构建、KulaCore 测试及聊天回归，全部通过。实际零调用窗口 `pid:90219` 的工作时长为 text，无展开按钮；独立工具窗口 `pid:91413` 点击后显示调用列表，未出现次数文案。README 中英文行为说明已同步，AGENTS 无持久规则变化。构建与回归产物沿用已有 `build/` 忽略规则。

## 复制按钮对齐与时间间距

助手回复底部复制按钮以负向 leading padding 补偿按钮内边距和图标留白，使可见图标与正文左边缘对齐，同时保留原来的点击热区。操作行 spacing 从 6pt 增至 16pt，拉开图标与时间戳。用户消息复制按钮不受影响。

重新执行 XcodeGen、Debug 构建和 KulaCore 测试均通过。README 使用说明不受此局部几何修正影响，AGENTS 规则与命令不变。

聊天回归全部断言通过。已检查新构建实际窗口 `pid:94514` 截图：复制图标左缘与上方正文和工作时长左缘对齐，时间戳间距已拉开。`git diff --check` 通过，临时构建产物沿用已有忽略规则。

## 用户气泡间距与工作时长字号

用户气泡与复制按钮单独组成 spacing 4pt 的 VStack，附件与正文仍维持 8pt。工作时长的普通文字、可展开按钮及运行状态统一复用 `AgentLayout.message`（14pt、400 字重）。

重新执行 XcodeGen、Debug 构建、KulaCore 测试和聊天回归均通过。实际检查附件用户消息窗口 `pid:99113` 的复制按钮显示，以及澄清回复窗口 `pid:99231` 的 14pt 工作时长。README 使用说明与 AGENTS 开发规则不变；构建产物沿用已有忽略规则。
