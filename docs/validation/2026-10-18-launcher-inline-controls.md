# 启动器内置固定与筛选按钮

## 行为与实现

- 空输入时在搜索框右侧显示固定、筛选两个 32 pt 图标按钮，图标为 17 pt；移除原搜索图标。
- 两个按钮共用外壳玻璃，没有独立玻璃背景；只保留悬停与按下反馈。
- 输入后隐藏按钮、让出文字空间；清空后立即恢复。窗口宽度保持 640 pt，空状态高 52 pt，不再随按钮显隐缩放。
- 删除两个独立按钮窗口、显隐状态、分离弹簧和窗口层级切换。筛选和更多菜单仍按需使用独立玻璃子窗口，原有菜单材质补偿保留。
- 保留外壳贴合玻璃的窗口尺寸、原生系统阴影、玻璃与内容双层圆角裁剪，不引入带透明间隙的扩大窗口。

## 实际验证

- `xcodegen generate` 成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData -skipPackageUpdates build`：`BUILD SUCCEEDED`。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：退出码 0，各测试套件通过；日志含系统 sandbox extension 提示。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --accessories`：浅色、深色均通过。覆盖无独立按钮表面窗口、640 × 52 几何、输入与清空、筛选来源隔离、菜单位置、固定与失焦、Escape 及连续六轮重新唤起。
- 通过真实回归窗口与 UI 自动化检查浅色首屏、输入结果、清空恢复及深色首屏。固定图标切换到填充状态，筛选状态切换 On/Off；点击按钮后辅助功能焦点始终在文本框，Escape 先关闭菜单。截图中右侧两个图标直接位于同一外壳内，没有单独圆形玻璃底。
- 交互预览使用 `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression --accessories-preview`，深色加 `--dark-only`；它们使用隔离测试存储，不更改系统主题。
- `git diff --check` 通过。构建日志与临时预览产物沿用已有 `build/` 忽略规则。

## 边界

没有对本次修改测量 GPU 时间、能耗或冷启动时长；只能确认删除了两个玻璃按钮窗口及其分离动画。未在本轮切换系统降低透明度或增强对比度设置；兼容表面分支保留原有实现。
