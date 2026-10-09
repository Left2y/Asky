# 透明启动器浮窗合成修正

日期：2026-10-09。范围：搜索胶囊的桌面玻璃合成；输入几何继续沿用 Figma Field 22:348。

## 问题与修正

用户的真实截图出现彩色噪点和不均匀透底。此前同一窗口内的渐变背景预览没有覆盖独立透明 NSPanel 的桌面合成，不能作为此问题的通过证据。截图不能单独确定 GPU 内部原因，相关材质、混合和阴影组合是本轮排查对象。

最终移除 luminosity 混合、SwiftUI 的额外描边与阴影，以及 NSPanel 的矩形窗口阴影。使用原生 Regular Liquid Glass 与普通 alpha 的 70% `Colors/background` 内容底层。减少透明度时关闭玻璃并使用同色不透明底层。

独立透明浮窗叠在密集黑字白底窗口上的比较显示，Clear tint 仍让背后的文字明显折射进输入区域；Regular 将背景字形柔化。深色背景不依赖 glass tint，输入前景、放大镜和提示按外层 colorScheme 显式解析，避免材质内部环境改变前景颜色。

没有修改搜索、键盘提交、模型请求或日历权限逻辑。720 × 60 pt、16 pt 输入、17 pt SF Symbol 和左右留白保持不变。系统玻璃仍不等价于 Figma 专用光学参数。

## 实际运行检查

| 检查 | 结果 |
| --- | --- |
| `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | 106 项测试、22 suites 通过；最终追加修改仅涉及 App 玻璃与前景解析 |
| `xcodegen generate` | 成功 |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build` | 最终代码 BUILD SUCCEEDED |
| 编译生产 LauncherView 与 LauncherController 的独立浮窗探针 | 透明 NSPanel 与文字背景分别属于两个窗口；最终浅色、深色屏幕区域截图均未见用户所示彩色噪点，背景文字柔化 |
| 深色探针输入框辅助功能树 | 确认搜索框获得焦点 |
| `git diff --check` | 通过 |

屏幕区域截图包含真实桌面合成的背景窗口与浮窗，而不是仅捕获透明窗口或同一窗口内的 ZStack。最终截图在 Retina 显示器取得，保存在 `build/figma-search-probe/floating-regular-light.png` 和 `floating-regular-dark.png`；测试数据为固定文本，不执行搜索 Provider 或工具。

本轮未测试所有壁纸、多显示器切换、系统减少透明度、提高对比度与长期 GPU 稳定性。探针已退出；未重启用户正在使用的 App，修复需在下次启动新构建后生效。

README: unchanged — 已有中英文所述输入尺寸、背景填充与原生玻璃仍适用，未改变使用方式或命令。AGENTS.md: unchanged — 现有指令层级与构建边界有效，无新开发规则。探针、构建日志和生成工程沿用既有忽略规则。已有验收草稿不属于本次任务。
