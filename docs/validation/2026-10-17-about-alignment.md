# 关于页面对齐与图标

- 品牌行与 Star 行统一为 56pt 图标栏、14pt 图文间距，名称/版本与 Star 标题/说明共用文字起点。
- Star 图标缩至 20pt，使用 40pt 高的居中槽；说明间距统一为 4pt。
- 顶部入口缩为 GitHub，复用 CommandGitHub 素材，以 14pt 原生按钮模板图显示，适配深浅色；Star 行按钮补充外链箭头。沿用 SettingsButton 与 ToolService 打开链接。

## 实际验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，Swift Testing 37 项。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py`：通过，输出 Settings native snapshots, authorization lifecycle and card drag restoration passed。
- 目视检查新编译的实际 SettingsWindow 截图 `build/settings-light-about.png` 与 `build/settings-dark-about.png`：文字起点、图标中心、按钮右边缘对齐，GitHub 模板图随外观切换。回归宿主显示的版本 0 属于测试 Bundle，不是产品版本变更。
- 本次未点击外部仓库链接，未重新验证 GitHub Star 状态探测。

README: unchanged — 仅调整布局与图标，使用方式、命令和配置均不变。
AGENTS.md: unchanged — 沿用既有 App 边界和验证流程，无新增持久规则。

构建与截图沿用 `.gitignore` 的 `build/` 规则，不提交生成产物。
