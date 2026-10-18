# 搜索展开窗口抖动定位与修正

日期：2026-10-18

## 根因与复现

前一版只移除了 ResultList 的 6 pt 位移，窗口展开仍向 NSWindow 传入小数顶边锚点与小数弹簧高度。AppKit 对窗口 origin 与 size 分别取整，导致实际顶边在动画中跳动 1 pt。原有专项检查允许 `inputDrift <= 1`，未把这一偏差判为失败。

将真实窗口检查收紧至输入框与窗口顶边偏移均小于 0.01 pt 后，修改前复现失败：`height=433.0, inputDrift=1.0, windowDrift=1.0`。中间帧为 `(415, 678, 640, 97)`。日志 `/tmp/asky-jitter-before.log`。

独立 AppKit 数值探针使用小数锚点 774.44，并遍历 501 个高度：原写法实际顶边集合为 `[774, 775]`；锚点和高度对齐后为 `[774]`。探针为 `/tmp/asky-window-quantization.swift`。

## 修正

- LauncherController 计算屏幕锚点时将 x/y 对齐至整数 pt。
- 显示链路保留连续弹簧值；仅在提交窗口帧时将高度取整，从同一个整数顶边计算 origin.y。
- 保留玻璃结构、圆角、阴影与原位淡入效果。
- 专项测试同时追踪窗口顶边与输入框，偏移必须小于 0.01 pt，失败时输出坐标。

## 实际验证

- `xcodegen generate` 与 README 的 Debug `xcodebuild`：BUILD SUCCEEDED。日志 `/tmp/asky-jitter-build.log`。
- KulaCore `swift test`：262 项 Swift Testing 测试通过。日志 `/tmp/asky-jitter-core.log`。
- `--result-motion` 真实窗口专项：浅色、深色通过。65 次采样中分别有 22、21 次处于展开中间高度，输入框偏移均为 0.0，窗口顶边通过小于 0.01 pt 的检查；键盘、清空、中断、重新打开通过。日志 `/tmp/asky-jitter-after.log`。
- 首次回归编译因并发构建修改 MarkdownUI.o 而停止。随后复制 Debug products 与 module maps 至 `/tmp/asky-jitter-derived`，使用 `ASKY_DERIVED_DATA=/tmp/asky-jitter-derived` 运行前后专项对照，避免共享构建产物竞争。
- 检视实际浅深色窗口截图 `build/launcher-result-motion-NSAppearanceNameAqua.png` 与 `build/launcher-result-motion-NSAppearanceNameDarkAqua.png`，布局正常；动态坐标结论来自采样。未重跑完整 LauncherWindow 回归。
- Debug App 签名严格检查通过，退出旧进程 8141 后启动新进程 17673，路径为仓库 `build/DerivedData/Build/Products/Debug/Asky.app/Contents/MacOS/Asky`。

仅提交本次窗口坐标修正、专项测试与文档，保留并发文件搜索改动。临时探针、日志与隔离产物在 `/tmp/`，截图沿用现有 `build/` 忽略规则。README 的固定输入框说明与现有命令仍准确；AGENTS.md 的边界和开发流程仍适用，均无需更改。
