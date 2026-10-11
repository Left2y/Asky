# 系统权限行布局

日期：2026-10-11。

- 每项权限左侧增加对应的 SF Symbol 彩色图标。
- 标题与状态上下排列，状态使用辅助文字样式；请求授权与打开系统设置按钮在行右侧垂直居中。
- 保留已有 ToolService 授权与状态刷新逻辑。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 `Packages/KulaCore`）：通过，19 个 Swift Testing 测试。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/run-settings-regression.py`：通过。新启动原生 NSWindow，并检查浅色和深色权限页渲染截图。
- 临时扩展同一回归 harness，在最小尺寸 820 × 560 下保存浅色、深色截图；目视确认可见权限行文案与按钮没有横向裁切。临时脚本在 `/tmp`，截图在已忽略的 `build/` 中。首次编译遇到其他构建同时修改 `Router.o`，重试通过。

未触发实际系统授权弹窗，未打包或安装 Release。

README 与 AGENTS.md 保持现状：本次仅修正权限行的视觉层级，没有改变使用方式、开发命令或架构边界。
