# 启动器结果列表布局修复验证

日期：2026-10-09。范围：启动器输入区、结果滚动区与 NSPanel 高度同步。

## 原因与修复

原浮窗初始高度为 72 pt，`NSHostingView.sizingOptions = [.preferredContentSize]` 没有配套窗口尺寸同步。结果滚动区只声明最大高度，搜索结果出现后依然被裁在原来的小窗口中。

现在结果滚动区按行数、行距和内边距获得明确高度，SwiftUI 报告完整内容高度，由控制器在布局完成后更新 NSPanel。窗口顶部保持不动，向下展开，整体最大 540 pt；状态提示占用的高度从结果区预算中扣除。隐藏后失效的布局回调不会影响下一次打开。

## 已运行检查

| 检查 | 结果 |
| --- | --- |
| `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | 102 项测试、20 个 suite 通过，包含真实 Runtime 与 MCP Bridge 测试 |
| `xcodegen generate` | 成功 |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build` | `BUILD SUCCEEDED` |
| 原生布局探针：空输入、1、3、40、2、0 条结果 | 高度分别为 56、113、205、540、159、56 pt，宽度保持 640 pt，顶部坐标保持不变 |
| 40 条结果，选择末项 | 保持 540 pt 的滚动窗口 |
| 最大结果列表附带状态提示 | 整体仍为 540 pt |
| 终端输出附带状态提示 | 整体为 394 pt，内容不被输入区挤压 |
| 隐藏后重新打开 | 恢复 56 pt 输入区，重新建立内容视图 |
| 同一探针编译修复前的 `LauncherView.swift` | 单条结果检查失败，窗口仍为 72 pt，复现原缺陷 |

布局探针直接编译生产 `App/Sources/LauncherView.swift`，仅用固定数据模型替代真实搜索与执行。探针、日志、位图和构建产物放在已有忽略目录 `build/launcher-layout-probe/`，不写入用户数据、不调用模型或系统工具。

通过 computer-use 对探针原生窗口做截图和方向键检查：输入框在顶部，三条结果独立排列在下方；按向下方向键后第二条高亮，输入焦点仍在输入框。截图检查使用实际窗口，不使用透明背景的视图缓存位图判断 Liquid Glass。

本地 Debug App 已重启，进程从 13707 变为 38574，加载新构建。本轮未完成真实搜索 Provider、不同外观、多显示器或全部辅助功能验收；上述原生窗口截图使用固定结果探针。

## 文档检查

README 的构建、测试与使用步骤保持有效，此修复落实设计系统已有的“高度随结果变化，最大 540 pt”要求。双语检查发现英文缺少现有中文的目录结构说明，已补齐相同的事实与路径；用法和命令保持不变。

为当前已有的独立 AgentRuntime、KulaCore 和 MCPBridge 补齐最小局部 AGENTS.md，只描述各自职责并链接既有权威文档，不改动根级规则。
