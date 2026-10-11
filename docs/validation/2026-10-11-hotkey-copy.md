# 快捷键设置文案精简

- AI 快捷键与启动器、剪贴板一致：成功时不显示“已注册”，也不生成空状态行；失败状态仍保留。
- 录制按钮只显示当前组合键；“点击录制”移至辅助功能描述，悬停提示为“录制快捷键”。录制中、无效组合键和占用提示保留。
- 三个恢复按钮统一为“恢复默认”，去掉重复组合键。

## 实际验证

- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `python3 App/Tests/run-settings-regression.py`：通过，生成浅色/深色页面截图；已查看深色快捷键截图。
- 重启 `build/DerivedData/Build/Products/Debug/Asky.app`（PID 92105），进入快捷键设置，检查实际窗口截图及辅助功能树：三个按钮仅显示当前组合键，AI 分组没有成功状态行或空行。
- 点击 AI 录制按钮：显示“按下组合键，Esc 取消”；按 Esc 后回到原组合键，未更改用户绑定。
- 本轮没有重新触发组合键占用错误；其原有处理分支保留。

README: unchanged — 文案精简不改变配置方式或开发命令。
AGENTS.md: unchanged — 未改变项目边界、构建命令或持久指导。
