# 设置窗口遵循 Dock 显示偏好

Dock 图标仅由“在 Dock 栏显示”偏好控制，打开或关闭设置窗口不再改变激活策略。README 中英文已同步说明。

## 实际验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --dock-only`：通过。实际创建设置窗口，验证默认 accessory 策略、设置窗口可见且获得键盘焦点、打开设置期间启停 Dock 开关、关闭窗口、偏好保存与模拟重新启动。
- `git diff --check`：通过。

回归使用临时数据目录，不修改用户偏好；截图位于已忽略的 `build/dock-settings.png`。未替换已安装应用。
