# 移除首次使用欢迎页

日期：2026-10-24

## 改动

- 删除欢迎窗口及其未提交的样式调整，移除首次启动和重新打开时的欢迎页分支、Debug 预览参数、自动更新静默判断中的欢迎窗口条件。
- 删除 `hasCompletedWelcome` 偏好字段及专用测试；已保存的该 JSON 字段由 Codable 忽略，不影响其余偏好读取。
- 删除欢迎页专用中英文资源和 README 描述，撤下已取消功能的验证记录，恢复添加欢迎页之前的启动逻辑。

## 已执行验证

- `xcodegen generate`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，退出码 0。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过，BUILD SUCCEEDED。
- 搜索 App 与 README：无 `hasCompletedWelcome`、`WelcomeWindow`、`showWelcome` 及欢迎页 Debug 参数残留。
- `git diff --check`：通过。

## 验证范围

本次未启动应用进行实际窗口交互验证，未打包或发布。构建产物沿用现有 `build/` 忽略规则。

## 文档维护

README 中英文同步删除欢迎页说明。AGENTS.md 无需修改：本次未改变模块边界、开发命令或持久规则。
