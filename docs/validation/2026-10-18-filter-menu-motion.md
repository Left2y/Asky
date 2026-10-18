# 启动器筛选菜单弹出动画

环境：macOS 27.0.1（26A434），Xcode Debug 构建，2026-10-18。

## 实现

筛选菜单沿右上角从 94% 放大至完整尺寸，并同步淡入。复用现有 `SurfaceSpring` 显示链路，response 为 0.24 秒，damping 为 0.9。窗口尺寸始终贴合玻璃外形；内容保持完整逻辑尺寸，随窗口坐标空间一起缩放，系统阴影随窗口变化。关闭菜单及隐藏启动器时停止显示链路；重新打开从初始状态开始。启用“减少动态效果”时直接显示完整菜单。

曾试用 AppKit `utilityWindow` 自动动画，实际逐帧录屏未呈现缩放，因此最终使用上述显式窗口动画，不将它描述为系统菜单自带动画。

## 实际检查

- `xcodegen generate`、README 中的 Debug `xcodebuild` 命令：通过。
- `codesign --verify --deep --strict build/DerivedData/Build/Products/Debug/Asky.app`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：262 项测试通过。首轮缺少 `AgentRuntime/dist/src/plugin-runner.js`，执行既有 `npm run build` 后重跑通过。
- 实际启动器窗口浅色、深色各录制三次菜单开关，并用 ffmpeg 提取打开过程的连续帧：确认逐步缩放、淡入，右上角保持锚定；菜单文字完整、圆角与阴影连续，没有透明外围画布或首次定位闪跳。
- 前台执行 `open -n -W --stdout /tmp/asky-menu-accessories-active.log --stderr /tmp/asky-menu-accessories-active-error.log build/LauncherWindowRegression.app --args --accessories`：浅色、深色均通过筛选隔离、输入位置、菜单独立窗口、固定/失焦/Escape 与反复显示检查。直接从后台执行二进制曾遇到显示链路未推进和重复显示断言失败；前台启动复核通过，未修改无关的附属按钮实现。
- “减少动态效果”分支已检查实现，本轮没有切换用户系统设置进行实际验收。

菜单动态预览入口（最终源码重新编译运行，浅色、深色均通过；重复运行可覆盖旧录屏）：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --accessories-preview --filter-motion
```

录屏为 `build/filter-motion-NSAppearanceNameAqua.mov` 与 `build/filter-motion-NSAppearanceNameDarkAqua.mov`。这些本地验证产物由现有 `build/` 忽略规则排除，不随源码提交。

README 同步两种语言的预览命令。AGENTS.md 无需调整：本次没有改变模块边界、构建流程或长期项目约束。
