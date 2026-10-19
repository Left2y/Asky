# MapKit Agent 地点与路线工具

日期：2026-10-19。本次接通主动对话中的地图能力；不改后台提醒规则、系统日程或用户设置默认值。

## 实现

- `maps_search_places`：通过 ToolService 调用 `MKLocalSearch`，最多返回 5 个带名称、地址、经纬度的候选；不自动获取当前位置。由 Agent 核对地点歧义。
- `maps_routes`：明确起终点坐标，支持驾车、公交、步行比较；支持指定出发时间或到达时间，后者先扣默认 10 分钟（可配置）的到场缓冲再查询，倒推建议出发时间。返回估计耗时、距离、出发/到达时间和已过时标记。查询失败的交通方式单独返回，全部失败则报错，不生成精确出发建议。
- 单次 MapKit 请求 20 秒超时，取消时停止原生查询；三种交通方式顺序查询，路线工具总上限 65 秒。地图查询只发送必要地点，无需 API Key。
- 通过既有 `.maps` 来源开关控制工具发现和执行，不依赖 `.web`。仅向内置 Agent 开放，未增加外部 MCP 暴露。设置补充地点发送说明及中英文本地化。
- Agent 指引优先使用地图工具，不用网页搜索摘要代替路线估计；多个日程逐段查询，考虑前一场结束时间、缓冲、偏好与车辆位置，不自动修改日程。缺少起点、地址歧义或路线不可用时明确处理。公交仅有 ETA，不提供线路、换乘、班次和票价；驾车耗时不等于含等车的打车耗时。

## 已执行检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：13 个测试产物共 286 项通过。其中 6 项 MapToolsTests 覆盖缓冲只扣一次、到达/出发参数传递、部分/全部失败、取消、无效输入、来源开关和 MCP 隔离。默认测试中的实时案例仅在环境变量启用时执行，实时结果见下一项。
- `ASKY_LIVE_MAPS=1 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MapToolsTests`（`Packages/KulaCore`）：6 项通过。通过真实 ToolService 搜索上海虹桥站、静安寺、东方明珠；查询两段路线的三种方式共 6 次 ETA；再查询约两小时后到达的驾车、公交共 2 次 ETA。8 次均返回有效耗时；指定到达时间的结果在日程开始前 10 分钟到达，已验证缓冲倒推。
- `npm test`（`AgentRuntime`）：11 项通过。新增真实 Runtime 进程 + mock OpenAI-compatible 服务测试，验证地图工具目录到达模型端、路线参数转发、原生结果回到模型、同一会话更新目录后地图工具移除。该测试以 mock 模型指令发起工具调用，不是模型自主选路质量验收。
- `python3 App/Tests/check-localization.py`：144 个 Swift 源文件的双语、格式参数及静态 key 检查通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：`BUILD SUCCEEDED`。
- `codesign --verify --deep --strict build/DerivedData/Build/Products/Debug/Asky.app`：通过。

实时复测样例（2026-10-19T14:44:15+08:00）：上海虹桥站 → 静安寺：driving 32.9 分钟、transit 37.3 分钟、walking 231.2 分钟；静安寺 → 东方明珠广播电视塔：driving 21.6 分钟、transit 32.8 分钟、walking 117.4 分钟。指定到达目标 2026-10-19T16:44:15+08:00，含 10 分钟缓冲的建议出发时间为 driving 2026-10-19T16:01:22+08:00、transit 2026-10-19T15:56:58+08:00。数值仅为本次返回结果，不代表固定耗时、真实旅程对照或未来准点保证。

## 验证边界与交付

- 未用用户真实日历或公司地址做网络测试；实时验证采用公开地标。
- 未在真实配置模型的聊天窗口验收自主选择工具、整天规划质量或视觉布局；未进行真实旅程对照、停车/等车成本、跨城、限流、断网或旧版 macOS 验证。
- 后台提醒目前仍未自动接入路线查询；本次补的是 Agent 可调用工具与编排指引。不能把这次改动称为全天自动规划器或后台提醒完整验收。
- 新 Debug App：`build/DerivedData/Build/Products/Debug/Asky.app`。开发构建从源码目录查找 `AgentRuntime/dist`，本次 `npm test` 已重新编译该目录；正式版安装包未更新。
- 日志保存在既有忽略目录 `build/maptools-validation/`，复用 `build/` 规则，无新增忽略规则。
- README 已同步中英文能力边界和实时测试命令；原生工具专题已记录参数与开关行为。
- AGENTS.md: unchanged — 工具沿用既有 ToolService 架构、SwiftPM/Node 测试和 App 构建流程，没有新增持久规则。
