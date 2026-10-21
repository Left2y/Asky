# 屏幕取色器提交前验证

2026-10-21，提交现有屏幕取色器改动前执行：

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，包含 `ScreenColorPickerTests`。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/check-localization.py`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --color-picker`：通过，覆盖搜索路由、自定义触发词、分类作用域及剪贴板颜色预览识别。
- `git diff --check`：通过。

未执行原生取色器的实际点击取色、Esc 取消及图标外观验收；上述自动检查不代表这些交互已经人工验证。
