# AI 窗口尺寸与圆角

## 改动

- AI 外壳从 32 pt 连续圆角改为复用 `LauncherLayout.shellCornerRadius`（26 pt）普通圆角，与搜索、剪贴板一致。SwiftUI 背景与内容裁剪、AppKit 玻璃层、窗口框架层使用相同半径与 circular 曲线。
- 宽度固定为共享的 `WindowMetrics.launcherWidth`（640 pt）；默认高度从 640 pt 缩至 560 pt，最小高度从 560 pt 缩至 480 pt，保留纵向调整。

## 已执行

- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData -skipPackageUpdates build`：最终代码构建成功。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：退出码 0，Swift Testing 汇总 310 项，2 项条件跳过（`liveOrcaCLISkillAndProjectDiscovery`、`bridgeBinaryEndToEnd(prefix:)`）。运行前准备了 AgentRuntime 依赖并完成 `npm run build`，未修改 Runtime 源码。
- 启动新构建的 Debug 可执行文件，PID 3397，路径为本仓库 `build/DerivedData/Build/Products/Debug/Asky.app/Contents/MacOS/Asky`。
- Orca 原生窗口读回 `Asky AI` 为 640 × 560 pt；截图检查空对话的问候、消息输入、附件、审批与发送按钮、顶部按钮完整可见，外壳圆角正常。
- 本地截图：`build/ai-window-compact.png`（构建产物，不提交）。
- `git diff --check`：通过。

## 边界

未发送真实模型请求，未覆盖长对话、历史页或浅深色模式组合。自动拖动尝试未改变窗口尺寸，因此不将该操作计为最小高度或手动缩放约束的实际验收；尺寸限制由窗口 minSize/maxSize 配置约束。
