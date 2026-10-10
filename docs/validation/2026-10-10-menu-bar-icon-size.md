# 菜单栏图标尺寸调整

用户反馈菜单栏 Logo 过大，显示尺寸从 18×18 pt 缩至 14×14 pt（宽高减少约 22%）。继续使用现有高分辨率单色模板资源，菜单项、点击区域和应用图标保持现有行为。

实际执行：

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：145 项测试、28 个测试套件通过。
- 结束旧 Debug 进程并通过 computer use 重新打开构建后的应用。当前自动化观察只返回应用窗口，未取得系统菜单栏截图；调整后的菜单栏实屏比例尚未确认。

README 中英文显示尺寸已同步。AGENTS.md unchanged：未改变架构或开发命令。临时日志沿用 `build/` 忽略规则。未打包 Release 或安装到 Applications。
