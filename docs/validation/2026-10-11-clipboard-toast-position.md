# 剪贴板 toast 顶部位置

- 将状态提示从底部移到可见弹窗顶部中央，距顶部 12pt。overlay 位于透明阴影外距之前，因此偏移以可见圆角面板为基准。
- 文字、图标、背景及复制逻辑保持原样，toast 不接收鼠标事件。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- 使用独立临时 ClipboardRegression 副本和测试数据启动真实 NSPanel，通过 Orca 截图确认顶部居中、顶部间距与搜索栏的 12pt 顶部内距对齐，下方图片与文字卡片不被 toast 遮挡。检查为深色模式。
- README: unchanged；局部位置调整没有改变使用方式或开发命令。
- AGENTS.md: unchanged；没有新增开发约束或架构边界。
