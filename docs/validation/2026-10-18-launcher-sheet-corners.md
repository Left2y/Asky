# 启动器原生 sheet 遮罩圆角

日期：2026-10-18。环境：本机 macOS 27 SDK，Debug 构建，720 × 430 pt 真实 LauncherPanel。

## 修复

原有圆角只裁剪玻璃与内容；AppKit 的原生 sheet 遮罩位于内容的窗口父容器，仍会填满透明的四角。`WindowSurface.updateCorners` 现在对无标题浮动窗口的内容父容器同步设置圆角、曲线与裁剪。原生 NSAlert、按钮和系统窗口阴影继续沿用现有实现。

新增 `--test-launcher-sheet` 隔离预览，使用真实 LauncherPanel、玻璃容器及退出确认 sheet，不初始化 AppModel、不读取应用数据、不执行工具。支持 `--preview-dark` 与 `--preview-legacy-material`，两个按钮均只结束预览。

## 实际检查

- `xcodegen generate`：通过。
- README 的 Debug `xcodebuild` 命令：通过，`BUILD SUCCEEDED`。现有 Xcode CoreDevice / Simulator 兼容提示未阻止 macOS 构建。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，264 项 Swift Testing 测试。
- 修复前真实窗口截图 `build/launcher-sheet-before.png`：左上角 `(0, 0)` 与 `(10, 10)` 的 RGBA 为 `(170, 170, 170, 153)`，证明遮罩覆盖了应透明的圆角。
- 修复后浅色截图 `build/launcher-sheet-after.png`：上述位置为 `(0, 0, 0, 0)`，圆角区域透明；正文区域与原生确认弹窗正常显示。
- 深色截图 `build/launcher-sheet-dark.png` 与旧材质截图 `build/launcher-sheet-legacy.png`：目视检查圆角正常；四个顶点及 `(10, 10)` 的 alpha 均为 0。
- 通过辅助功能点击取消或关闭后，对应隔离预览进程退出。自动化返回时窗口已消失，工具报告后置辅助功能读取失败，因此不以动作返回码单独认定通过。Escape 因窗口未聚焦未验证通过。
- 截图保留在已忽略的 `build/`，未安装或覆盖 `/Applications/Asky.app`。旧材质为当前系统上的回退预览，未声称在 macOS 15 实机验收。

## 维护

README: updated，中英文同步隔离预览命令。AGENTS.md: unchanged，现有玻璃表面规范、模块边界和构建流程不变。
