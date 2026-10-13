# 通用设置菜单栏图标开关

- 在“通用 › 启动”增加“显示菜单栏图标”行，默认开启；通过 AppModel 的偏好变更回调更新现有 NSStatusItem.isVisible。
- 偏好保存沿用本地设置存储；旧版本没有此字段时默认开启，启动时读取保存值。隐藏图标不改变快捷键注册。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）退出码 0，全部测试通过。
- `xcodegen generate` 与 README 中的 Debug xcodebuild 命令通过。
- 初次运行遇到 Asky.debug.dylib 的 Team ID 签名校验失败；使用同一构建命令加 `ENABLE_DEBUG_DYLIB=NO` 后构建通过，实际应用成功运行。
- 新构建的实际设置窗口截图及辅助功能树确认新增行位于“启动”分组。通过真实控件切换 on → off，退出并重新打开应用后回读仍为 off，再切回 on。
- 实际 UI 检查验证了开关和重启保存；未单独捕获系统菜单栏图标的前后截图。显示与隐藏使用 AppKit 的 NSStatusItem.isVisible。
- README 中英文已同步新设置。AGENTS.md 检查后无需修改：本次未改变模块边界或开发流程。
