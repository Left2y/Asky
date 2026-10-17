# 复制提示条尺寸修复

## 原因与修改

独立表面改造后，`SurfacePanel.fittingSize` 使用 NSHostingController 测量提示条得到 95 × 35pt；实际 NSHostingView 的理想宽度是 96pt。差 1pt 会让“已复制”换行，内容超出窗口边界，圆角背景被裁成方框。使用真实 SurfacePanel 复现了截图中的文字换行和方形背景。

测量宽度增加 1pt 布局余量，仍受调用方 maxWidth 限制。继续使用既有提示条颜色、12pt 圆角、边框和系统窗口阴影。

## 已执行验证

- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild`：通过。
- `cd MCPBridge && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`：通过。
- `cd AgentRuntime && npm ci && npm run build`：通过，补齐核心插件测试所需的本地 runner。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。首次运行因缺少 `AgentRuntime/dist/src/plugin-runner.js` 失败；补齐后重跑全部通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --toast-surfaces`：通过。实际显示 SurfacePanel，在浅色和深色下分别检查“已复制”与“无法复制：原始内容已不可用”，窗口尺寸分别为 96 × 35pt、214 × 35pt；断言窗口保持测量尺寸、角落透明、内部不透明。
- 已目视检查回归生成的四张原生窗口内容截图：文字单行、四周留白、圆角与边框正常。截图位于被忽略的 `build/clipboard-toast-{light,dark}-{copied,error}.png`。

回归入口在初始化 AppModel 之前执行，不改写用户剪贴板或历史。本次未替换已安装的应用，也未打包发布。

README 已同步中英文回归命令。AGENTS.md 检查后保持不变：未改变模块边界、工具链或现有验证约定。
