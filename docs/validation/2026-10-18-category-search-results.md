# 筛选分类增加搜索结果数量

日期：2026-10-18。

## 问题与改动

原有筛选会重建 provider 并重新查询，但无论“全部”还是单一分类，都使用 SearchCoordinator 默认的每来源 8 条上限；合并批次又统一截到 40 条。因而文件、应用或快捷指令即使有更多命中，分类页也不会增加结果。

- 复用现有筛选菜单，不增加新页面或搜索入口。
- “全部”保留每来源 8 条、合并批次 40 条的快速候选策略。
- 应用、文件、快捷方式、快捷指令分类改为向 provider 请求最多 200 条，合并和最终展示上限同步为 200，支持已有列表滚动与方向键选择。
- 保留当前输入；切回“全部”恢复快速候选数量。现有查询取消和 revision 校验继续防止旧分类结果回写。
- 200 是结果数量上限，不是首屏条数，也没有第 201 条之后的自动加载。匹配数量不足时只展示实际命中。

## 实际执行

- `xcodegen generate`：通过。
- README 中 Debug `xcodebuild` 命令：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：267 项通过，13 个测试目标。
- `python3 App/Tests/check-localization.py`：通过，139 个 Swift 源文件。
- `python3 App/Tests/run-launcher-window-regression.py --filter-search`：通过。Aqua / Dark Aqua 均验证文件 8 → 200 → 8、应用 85、快捷指令 65、快捷方式 200；保留查询、切换分类后迟到批次不覆盖、方向键可到达第 200 条，真实 NSScrollView 已滚动到下方。
- 已查看 `build/category-search-NSAppearanceNameAqua.png` 与 `build/category-search-NSAppearanceNameDarkAqua.png`，最后一项 `report file 199` 可见并选中。窗口检查使用固定 provider 构造足量命中，不声称测试数据来自真实用户文件或已安装应用。
- `git diff --check`：通过。
- README 中英文同步分类搜索数量与原生回归入口；PRD 同步分类行为和上限边界。
- AGENTS.md 维护检查：无需修改，沿用现有 App 和核心包边界及构建验证规则。
- 构建、截图、测试临时资源及检查日志沿用既有 `build/` 忽略规则，不纳入提交。
