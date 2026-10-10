# 搜索结果列表顶部间距

- 移除结果列表容器顶部的 12 pt padding，保留底部 12 pt 和水平 12 pt padding。
- 列表高度计算同步减少 12 pt，分类标题内部间距保持原样。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：127 tests / 27 suites 通过。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- 未进行运行中的原生窗口视觉验证；重新启动新构建后可查看效果。
- README 与 AGENTS.md 无需修改：本次仅调整局部间距，未改变使用方式、开发命令或模块边界。
