# 设置侧栏与通用配置合并验证

- 图标底色 26×26 → 22×22 pt；SF Symbol 14 → 12 pt；圆角 6 → 7 pt，采用 continuous 曲线。
- 移除独立外观侧栏页，主题选择器保留在“通用 › 外观”，位于“启动”之后。默认打开通用；旧 appearance 页面标识通过现有 resolve 回退到通用。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `xcodegen generate` 与 README 中 Debug xcodebuild 命令：通过。
- `python3 App/Tests/run-settings-regression.py`：通过，覆盖所有页面的浅色/深色标题同步、权限页路由和最小窗口布局。
- 使用新编译的 SettingsRegression --preview 打开真实 AppKit 设置窗口，并通过屏幕截图确认 9 个侧栏条目、缩小的圆角图标与通用中的主题选择器。离屏 cacheDisplay 截图缺失侧栏，因此侧栏视觉以可见窗口截图为依据。
- 未打包 Release 或安装。回归程序和截图复用 build/ 的已有忽略规则。
- README: updated，中文与英文同步主题位置；AGENTS.md: unchanged，没有新增开发命令或架构边界。
