# AI 历史切换顶部位置验证

- 原因：对话顶部高度为 56 pt，历史顶部高度为 60 pt；居中的按钮随切换下移 2 pt。
- 修复：顶部统一为 56 pt，仅保留 12 pt 水平内边距。搜索框保持 36 pt，按钮保持 32 pt；内容切换动画保留。

## 实际检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 `Packages/KulaCore`）：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过，日志为 `BUILD SUCCEEDED`。
- 使用实际 `AgentView` 与 `AgentWindowController` 编译独立原生预览，临时数据与现有会话隔离；通过 computer use 点击历史、返回、再次进入历史。截图确认四个按钮的圆形边界、中心和顶部下方分隔线位置一致，搜索框无裁切。

预览首次编译遇到 SDK 选择不一致，随后显式指定 Xcode；第二次遇到其他任务改写共享构建产物，改用 `build/HeaderPreviewDerivedData` 副本后编译并运行成功。预览和构建副本由已有 `build/` 忽略规则排除，不纳入源码。

README 与 AGENTS.md 保持不变：此次仅修正顶部布局偏移，不改变使用方式、开发命令或架构边界。工作区内其他任务修改未纳入本次提交。
