# sw 应用窗口搜索验证

日期：2026-10-21。

## 实现范围

- `sw` 回车或 `sw 空格` 进入独立窗口搜索，支持搜索指令名称与自定义触发词。
- 空查询列出其他常规应用通过 Accessibility 暴露的窗口；按窗口标题与应用名筛选，不按应用或标题合并，不截断为普通搜索的 8 条或分类的 200 条。
- 当前面板保留窗口引用，退出后释放；重新进入时刷新。目标用 AX 身份校验，不以标题重新猜测。
- 切换恢复最小化窗口并置前；恢复动画期间有界重试 AXRaise，关闭窗口提示重新搜索。系统访问全部位于 ToolService。

## 实际执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/WindowSearchDerivedData build`：通过，最终异步切换实现已重新构建。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：通过，报告共 291 项，包含 1 项环境性跳过 `liveOrcaCLISkillAndProjectDiscovery`；新增窗口匹配测试通过。
- `ASKY_DERIVED_DATA="$PWD/build/WindowSearchDerivedData" DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --window-search`：通过。检查入口选择、空格进入、自定义触发词、模式内指令文本、退出保留查询、空查询退格、取消后不回写结果。测试进程辅助功能权限为 true，因此未执行缺少权限分支。
- 将 `App/Tests/WindowSearchLiveRegression.swift` 用相同 Debug 模块、对象文件、SDK 及 Swift 6 编译后运行：通过。独立测试应用创建两个相同标题的真实 NSWindow，其中一个最小化；枚举返回两条，分别切换后的 key-window 通知确认两个不同窗口，最小化窗口恢复；关闭其中一个后，旧目标返回 unavailable。测试应用退出并清理临时目录。已提供 `--window-search-live` 入口，完整 runner 的该参数尚未另行运行。
- `python3 App/Tests/check-localization.py`：通过。
- `git diff --check`：通过。

## 验证边界与工作区

- 未验证跨 Space、全屏、多显示器、不同第三方应用的 Accessibility 实现，以及真实键盘鼠标操作与浅深色外观。
- 初次真实测试暴露最小化恢复期间立即 AXRaise 会失败；增加短暂有界重试后，未经额外激活干预的真实双窗口测试通过。
- 新构建位于 `build/WindowSearchDerivedData/Build/Products/Debug/Asky.app`，没有替换用户当前运行的应用。
- 工作区有多项既存及并行改动，窗口搜索与它们在 LauncherModel 的枚举和指令表等位置重叠，未创建混合或不完整提交；未修改既有暂存内容。构建产物沿用 `.gitignore` 的 `build/` 规则。
- README: updated，中英文同步使用方式、权限和测试入口。
- AGENTS.md: unchanged，沿用原生 App 与 ToolService 的现有边界。

## 窗口结果应用图标修正

- 根据用户截图，窗口结果从统一紫色窗口图标改为所属应用的真实 Logo。`LauncherModel` 按窗口 ID 从当前快照取 `applicationPath`，结果行经 ToolService 已有图标缓存读取；`sw` 指令与输入模式图标保持窗口图标。
- 未改变窗口目标 ID、搜索匹配或切换行为。README 中英文同步该显示规则。
- 再次执行 `xcodegen generate`、同一独立 DerivedData 的 Debug `xcodebuild`、核心 `swift test`、`check-localization.py` 与 `git diff --check`：通过；核心套件仍有 1 项既有环境性跳过。
- 临时原生预览使用真实 LauncherController 与当前窗口快照。通过 computer-use 获取到辅助功能窗口树，但截图为全黑；再次请求 restore 时返回 window_not_found。未将这次截图记作图标外观验收，也未替换当前运行的旧 Debug 应用。
- README: updated；AGENTS.md: unchanged。相关源码仍与上一轮未提交功能重叠，未创建不完整或混合提交；没有新增忽略规则。
