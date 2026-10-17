# 来源设置图标视觉尺寸

- 修复：来源设置列表的 Chrome 与个人记忆图标增加 1.125 倍视觉缩放，补偿白色底板内标志的视觉分量；保留原有 24 pt 布局槽、行高与文字对齐。调整仅应用于该设置列表。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过，日志 `build/source-icons-build.log`。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，37 tests / 9 suites，日志 `build/source-icons-core-test.log`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py`：通过，日志 `build/source-icons-settings.log`。检查新构建原生窗口的 `build/settings-light-sources.png` 与 `build/settings-dark-sources.png`：两项图标均已放大，无裁切、重叠或文字位置变化。
- README 与 AGENTS.md：无需修改；本次为局部视觉修复，未改变使用方式、开发命令或架构边界。
