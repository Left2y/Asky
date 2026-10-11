# 剪贴板 toast 外侧顶部位置

- 将状态提示放在整个可见弹出层外侧上方并水平居中，toast 底边与面板顶边间隔 12pt。使用 visualEffect 按 toast 实际高度加 12pt 向上偏移，覆盖层位于面板裁切之后和透明阴影外距之前。
- 文字、图标、背景及复制逻辑保持原样，toast 不接收鼠标事件。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- 使用独立临时 ClipboardRegression 副本和测试数据启动真实 NSPanel，通过 Orca 截图确认toast 完整位于弹出层外侧上方，底边与面板顶边间隔 12pt，搜索栏及下方图片与文字卡片不被 toast 遮挡。检查为深色模式。
- README: unchanged；局部位置调整没有改变使用方式或开发命令。
- AGENTS.md: unchanged；没有新增开发约束或架构边界。
