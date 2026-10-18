# 搜索窗口宽度 640 pt

将 `WindowMetrics.launcherWidth` 从 720 调整为 640 pt。空状态搜索框与右侧按钮的总宽度为 640 pt，展开搜索面板宽度为 640 pt；剪贴板列表继续采用 720 pt。同步设计系统和既有宽度回归断言。

## 实际验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py`：宽度断言通过，实际窗口为 640 × 433 pt，初始输入位置漂移 0 pt；完整运行未通过，停在滚动后选中项保持断言（selection 1/8，文本与焦点保持）。未将完整回归记为通过。
- 使用上述脚本编译的 `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression --accessories`：浅色、深色均通过；覆盖 640 pt 总宽度、按钮收放、重复打开、输入位置与筛选菜单。
- 同一回归程序 `--compact-results`：浅色、深色均通过；实际窗口截图已查看，长文件名截断、混合结果和空输入胶囊布局正常。
- 截图及编译产物位于 `build/`，沿用既有忽略规则。

## 文档与指令检查

README: unchanged — 此次仅调整搜索宽度，已有使用方式和开发命令仍准确。

AGENTS.md: unchanged — 未改变架构边界、独立子项目或开发流程。
