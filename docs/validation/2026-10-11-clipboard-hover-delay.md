# 剪贴板悬停预览延迟

- 卡片进入悬停后等待 1500 ms 才展示完整预览；移开、关闭面板等操作继续取消待执行任务。
- README 中英文同步行为及定向回归命令。

## 实际运行

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：145 项测试通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `python3 App/Tests/run-clipboard-regression.py --hover-delay`：通过。实际原生窗口中，1 秒悬停时不可见，移开后等待 700 ms 仍不可见；重新悬停 1700 ms 后可见，关闭面板后预览释放。
- 完整 `python3 App/Tests/run-clipboard-regression.py` 未通过：运行中出现面板被关闭，以及后续预览定位/可见性断言失败。本次未将完整套件记为通过。定向计时检查使用固定面板和忽略鼠标事件，避免实时指针/外部点击干扰主动触发的控制器回调。

验证在当前工作区执行，保留了任务前已有的剪贴板定位、搜索框粘贴等未提交修改。未进行真实鼠标连续悬停的人工验收；未打包 Release 或安装本地应用。

AGENTS.md: unchanged — 没有改变模块边界或开发约定。
README: updated — 中英文同步 1.5 秒预览延迟和实际运行的回归入口。
