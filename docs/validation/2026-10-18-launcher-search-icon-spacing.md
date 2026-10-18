# 启动器搜索图标间距

将 `LauncherLayout.inputTrailingPadding` 从 28 pt 调整为 22 pt，装饰性搜索图标向右移动 6 pt，使其更贴近胶囊右侧圆角。

## 实际验证

- `xcodegen generate`：通过。
- README 的 Debug `xcodebuild` 命令：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 `Packages/KulaCore`）：267 项通过。初次未指定 Xcode 工具链时缺少 `Testing` 模块，切换后通过。
- `python3 App/Tests/run-launcher-window-regression.py --accessories`：编译成功，首次浅色运行在分类切换的纵向位置断言失败。
- 使用同一新编译的 `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression --accessories --dark-only`：通过。
- 再运行同一二进制 `--accessories`：浅色和深色均通过，包括分类隔离、输入框几何、失焦、Escape 和重复打开。首次失败未稳定复现。
- 检查本次运行生成的实际窗口截图：浅深色搜索图标右移、尺寸与垂直居中保持正常。截图位于忽略的 `build/launcher-search-icon-NSAppearanceNameAqua.png` 和 `build/launcher-search-icon-NSAppearanceNameDarkAqua.png`。

README 与 AGENTS.md 无需修改：本次仅调整现有布局间距，开发命令、用法与架构约束均未改变。
