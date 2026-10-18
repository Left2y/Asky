# 剪贴板卡片操作图标定位

- 固定标记与悬停更多菜单共用右上角 28 × 28 pt 槽位，顶部 12 pt、右侧 16 pt，与来源图标中心处于同一水平线。原固定标记仅按 12 pt 字形宽度靠右排列，切换为 28 pt 菜单时中心会横移 8 pt。
- `xcodegen generate` 与 README 中的 Debug `xcodebuild` 命令执行通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --card-actions` 执行通过；已查看固定、悬停及实际原生菜单截图。菜单显示复制、取消固定、删除，点击 dots 未触发复制。
- 截图位于被现有 `build/` 规则忽略的 `build/clipboard-card-pinned-actions.png`、`build/clipboard-card-hover-actions.png`、`build/clipboard-card-actions-native.png`。
- KulaCore：默认 Command Line Tools 执行 `swift test` 因缺少 `Testing` 模块失败；指定 Xcode 的 `DEVELOPER_DIR` 后执行完成，但 `PluginTests.nativeWorkerRoundTripAndPolicy` 有 4 个 issue（worker 返回 pendingVerification、output/readback 为空，日志同时有 sandbox_extension_consume 失败），全套未通过。剪贴板访问测试通过。
- README: unchanged；此次仅修正已有控件对齐，不改变使用方法或开发命令。
- AGENTS.md: unchanged；未改变模块边界和持久开发约定。
