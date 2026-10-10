# 搜索浮窗玻璃层次与磨砂调整

用户对照其他搜索浮窗要求增强玻璃重量，并在同一色块背景下指出上一版磨砂偏重。本次降低背景遮盖、加强悬浮投影，并将底层 HUD 磨砂换为 Menu 材质，保留更多大块背景轮廓。

## 最终实现

- 仅搜索外壳使用浅色 35% / 深色 45% 的语义背景填充；全局 white70 / black70 token 不变。
- 独立 NSVisualEffectView 使用 `.behindWindow`、`.menu`、`.active`，其上仍为原生 Clear Liquid Glass。
- 外部阴影浅色 alpha 从 0.12 提至 0.24，深色为 0.40；40 pt 半径、12 pt 偏移及透明画布尺寸不变。
- 输入、结果、键盘行为及既有列表几何保持原样。减少透明度时继续跳过磨砂和玻璃，使用不透明语义背景。

## 实际运行的验证

- 核心包 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：129 项测试、27 suites 通过。
- `xcodegen generate` 与 README 中的 Debug `xcodebuild`：BUILD SUCCEEDED。
- `python3 App/Tests/run-launcher-window-regression.py`：浅色/深色通过；初次结果、连续输入、结果变化的输入框漂移均为 0 pt。
- 独立透明 NSPanel 和独立色块/16 pt 文字背景窗口的桌面合成检查：Menu 材质比本轮 HUD 版本保留更清楚的色块分界，背景文字仍不可辨读，前景 Safari 结果文字清晰。最终浅色/深色收起状态已查看。
- 本地截图：`build/validation/launcher-glass-weight-menu-frost.png`（结果列表）、`launcher-glass-weight-final-light.png`、`launcher-glass-weight-final-dark.png`。截图及临时探针沿用 `build/` 忽略规则。

视觉探针使用生产视图及隔离数据库、模拟搜索源。最终探针仅将测试 Panel 的 `canBecomeKey` 设为 false，避免接收用户键盘输入；输入行为由未修改的原生窗口回归覆盖。系统减少透明度设置未切换，不声称该分支已视觉验收；原生材质参数不声称与参考应用逐项等价。

临时测试窗口会退出。未安装或打包发布版本，也未重启用户正在运行的产品进程；重新打开新 Debug 构建才会应用最终材质。

README: updated，中英文同步填充和投影说明。AGENTS.md: unchanged，未改变模块边界、开发命令或持久规则。既有滚动高度、链接/书签及其他文档改动不纳入本次提交。
