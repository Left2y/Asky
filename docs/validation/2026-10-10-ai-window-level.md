# AI 窗口取消持续置顶

## 改动

- AI 对话窗口由 `.floating` 改为 `.normal`，允许其他应用的普通窗口覆盖。
- 移除 `.canJoinAllApplications` 与 `orderFrontRegardless()`；保留跨桌面显示、主动打开时激活和最小化恢复逻辑。
- README 中英文同步窗口层级说明。

## 已执行验证

- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：116 个测试、23 个套件通过。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：`BUILD SUCCEEDED`。
- `git diff --check`：通过。

## 验证边界

未重启正在运行的 App，未执行真实桌面窗口切换验收。需退出旧进程并打开新构建，检查 AI 窗口可被其他应用覆盖，以及菜单栏打开、Finder 重开和最小化恢复仍能正常唤起。
