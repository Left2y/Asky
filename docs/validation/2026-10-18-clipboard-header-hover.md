# 剪贴板标题栏按钮悬停反馈

- 筛选与固定按钮复用 `LauncherActionButtonStyle`，补充显式悬停及按下高亮；32 × 32 的 Capsule 保持圆形玻璃外观，沿用减少动态效果支持。
- `xcodegen generate`、README 的 Debug `xcodebuild` 命令及 `codesign --verify --deep --strict` 通过。
- 已启动新 Debug 并查看实际剪贴板窗口：两个圆形按钮与无障碍标签存在。自动化工具未提供独立移入指针接口，后续交互又被并发重建中断，未将悬停视觉验收记为通过。
- KulaCore `swift test` 未全通过：`PluginTests.nativeWorkerRoundTripAndPolicy` 缺少 native runner，并导致调用结果断言失败。
- `run-clipboard-regression.py --filters` 未通过：`ClipboardRegression.swift:177` 的筛选菜单右边缘位置断言失败；该测试使用固定的标题栏坐标，本次未修改菜单布局或该测试，也未验证基线是否同样失败。
- README: unchanged；恢复既有反馈，不改变使用方式或开发命令。
- AGENTS.md: unchanged；未改变模块边界、工具链或长期约定。
- 构建与回归产物沿用既有 `build/` 忽略规则。
