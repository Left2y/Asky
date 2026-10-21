# 取色默认触发词改为 co

默认触发词从 `color` 改为 `co`，保持 `colorPicker` 命令标识及用户自定义触发词。中英文 README 同步更新。

2026-10-21 实际执行：

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --color-picker`：通过，覆盖 `co`、`CO`、中文搜索、自定义触发词、分类作用域和剪贴板颜色识别。
- `git diff --check`：通过。

未执行原生取色器点击取色与 Esc 取消的人工验收。本次不改变取色交互与外观。
