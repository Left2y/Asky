# 历史列表移除新对话按钮

按用户提供的截图反馈，移除 `AgentView.history` 顶部带 `square.and.pencil` 图标的“新对话”按钮。历史列表直接显示已有对话，搜索、选中、重开与删除逻辑保持原有实现。

实际执行：

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：117 tests / 23 suites 通过。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `git diff --check`：通过。

未进行运行中窗口的视觉验收；构建不会替换旧进程，重新打开新构建后可查看结果。

README 与 AGENTS.md 检查：此项局部界面修正不改变已记录的使用方式、开发命令或架构边界，均无需更新。
