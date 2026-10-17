# 来源图标内部标志比例修复

- 根因：Chrome、快捷指令、信息及 Asky 素材在 256 px 渲染下，半透明阈值 128 的底板均为 206 px 宽；Chrome 与 Asky 的内部标志有更多白色留白。之前整体放大 1.125 倍同时放大了底板，未单独校正标志比例。
- 调整：移除整体缩放；保留原图底板、系统阴影与 24 pt 布局槽，在中心 18 pt 圆形区域叠加放大的原图标志，Chrome 1.14 倍、个人记忆 1.4 倍。仅作用于来源设置列表。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过，日志 `build/source-marks-build.log`。
- `Packages/KulaCore` 中执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：37 tests / 9 suites 通过，日志 `build/source-marks-core.log`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py`：通过，日志 `build/source-marks-settings.log`。人工检查新生成的原生窗口截图 `build/settings-light-sources.png` 与 `build/settings-dark-sources.png`，两个内部标志均明显增大，底板与相邻系统图标保持相同尺寸，文字对齐不变。
- README: unchanged；仅局部视觉修复，使用方法和开发命令未变化。
- AGENTS.md: unchanged；未改变模块边界、验证流程或持久开发约定。
- 检查脚本、图标采样、截图、编译输出和日志均在已有 `build/` 忽略规则下，无新增忽略规则。
