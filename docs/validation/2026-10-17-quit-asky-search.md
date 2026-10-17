# 搜索关闭 Asky 验证

日期：2026-10-17。工作区：`/Users/niallyoung/orca/Asky`。

## 行为

默认搜索完整输入 `asky`（忽略大小写和首尾空白）时，第一项是带白底红色品牌轮廓图标的“关闭 Asky”，原有应用结果保留。点击或回车使用统一 `AppDialog` 原生 Alert 二次确认。取消保留搜索窗口；确认调用 `NSApp.terminate`，复用应用现有 `ApplicationTermination` 清理流程。其他关键词、终端作用域和应用筛选不增加该命令；重复执行不会叠加确认弹窗。

## 实际运行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，全部 13 个 Swift Testing 测试运行、共 261 项测试通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-quit-asky-regression.py`：通过。实际创建启动器窗口和 Alert sheet，检查异步结果不改变首位、大小写与空白匹配、非匹配输入和筛选、重复提交、取消保留窗口、确认仅触发一次退出回调；浅色/深色均通过。回归替换退出回调以便检查确认后的状态，不退出已安装的 Asky。
- `plutil -lint App/Resources/en.lproj/Localizable.strings App/Resources/zh-Hans.lproj/Localizable.strings`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-application-termination-regression.py`：其中独立原生进程退出测试通过，验证异步清理、重复退出请求和实际进程结束；后续更新器测试失败。现有测试从 Swift 字符串直接提取 shell，未展开 `\(lsregister)` 插值，导致 shell 语法错误；此项不记为通过，未修改更新器。

第一次窗口回归在取消后的第二次弹窗检查失败；等待系统 sheet 动画完成并显式执行退出结果后通过。第二次编译被并行修改的 `SurfaceWindow.swift` 中断；回归脚本现使用源码快照，避免编译期间输入变化。

## 视觉检查

已查看实际窗口截图，确认白底红色图标、排序与浅色/深色 Alert 的文字和按钮布局。截图保存在已忽略的 `build/`：

- `quit-asky-results-NSAppearanceNameAqua.png`
- `quit-asky-results-NSAppearanceNameDarkAqua.png`
- `quit-asky-alert-NSAppearanceNameAqua.png`
- `quit-asky-alert-NSAppearanceNameDarkAqua.png`

构建与回归使用了工作区当时的并行界面改动；本次提交仅包含退出搜索功能，不包含其他未提交的布局修改。未替换 `/Applications` 中的应用，未发布 Release。
