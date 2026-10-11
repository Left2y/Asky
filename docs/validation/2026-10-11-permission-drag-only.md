# 移除自动注册，仅保留拖拽授权

日期：2026-10-11。

## 修改

- 删除 `SystemPermissions.registerForAuthorization`：屏幕录制的 ScreenCaptureKit 内容枚举和辅助功能的 `AXIsProcessTrustedWithOptions` 提示都会弹出 macOS 系统权限提示，与拖拽授权重复。
- 授权浮窗未授权时只清除本应用旧条目，清除完成后开放拖拽卡片；拖入系统设置即完成添加与开启。
- 浮窗提示文案去掉“完成系统提示”“打开开关/列表中没有 Asky”等描述，中英文本地化及 README 同步。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `python3 App/Tests/run-settings-regression.py`：通过。准备阶段改为等待旧条目清除，覆盖清除完成前不打开设置、准备中取消后不继续。

## 未验证

未在真实 TCC 环境手动确认首次授权不再弹出系统提示；需安装后复测屏幕录制和辅助功能的首次授权。本次没有打包、安装或发布。
