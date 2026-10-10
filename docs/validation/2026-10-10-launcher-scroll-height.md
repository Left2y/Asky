# 搜索列表滚动条与高度调整

日期：2026-10-10。

## 改动

- 结果列表最大高度由 300 pt 增至 400 pt（8 个 50 pt 菜单项的高度，分类标题共用预算），继续受屏幕可用高度限制。
- 隐藏结果列表的原生滚动指示条，保留滚轮、触控板与键盘滚动。
- 搜索内容按外壳圆角裁切，避免内容绘制到圆角外；玻璃背景、边框与阴影保持原有布局。
- README 中英文尺寸说明同步；原生窗口回归新增长列表 400 pt 高度断言。

## 已运行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：128 tests / 27 suites 通过。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `python3 App/Tests/run-launcher-window-regression.py`：浅色、深色通过；各 130 次采样，窗口高度 729 pt（含 264 pt 阴影画布），输入位置漂移 0 pt。清空输入、结果减少与关键词输入检查通过。
- `git diff --check`：通过。

## 验证边界

未进行截图视觉验收、真实滚轮/触控板操作或多显示器检查。未重启用户正在运行的 App；需重新打开 Debug 构建查看变化。
