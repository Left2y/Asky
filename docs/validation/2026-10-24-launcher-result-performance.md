# 启动器结果渲染性能

日期：2026-10-24。基线：`245b8f4`。参考 Tinycast 的懒加载列表、后台图标绘制、展示缓存和显式滚动原点；没有引入其文件索引，也没有修改 Spotlight、查询防抖、结果排序或回车路由。

## 实现

- 分组与结果展开为一个带稳定标识的 LazyVStack，按需创建结果行。列表顶部使用独立锚点，输入变化和回到第一项时直接定位原点；鼠标选择以具体行号标记，避免合并更新时错误跳过键盘滚动。
- ToolService 中的独立 actor 串行准备系统图标与文件类型，图标绘制成 96 px 位图后发布。视图只读取缓存或已加载的数据；离屏取消的排队任务不开始系统读取，迟到资源不写回已取消的行。
- 展示缓存配置为 128 项、8 MiB 和 5 秒有效期，预热写入同一缓存。缓存不保存文件搜索结果或文件存在性；NSCache 限制不是严格的进程内存上限。
- 应用、文件、窗口、快捷指令、浏览器及终端结果按需加载自己的图标，不再为每一条结果同步解析终端应用图标。相同结果数组不重复发布。

## 实际验证

工作区同时存在另一项窗口生命周期与焦点诊断改动，因此将基线源码与本次补丁复制到 `build/search-performance-snapshot`，排除并行改动后验证。产物分别使用 `build/DerivedData-search-performance` 与 `build/DerivedData-search-performance-final`。本记录验证本次补丁，不代表并行改动合并后的完整工作区验收。

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：310 项通过。新增测试覆盖冷缓存位图绘制、缓存复用、目录扩展名不作为类型、取消任务不启动冷读取。
- 快照目录执行 `xcodegen generate`，再执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath /Users/niallyoung/orca/Asky/build/DerivedData-search-performance-final -clonedSourcePackagesDirPath /Users/niallyoung/orca/Asky/build/DerivedData-search-performance/SourcePackages build`：最终源码构建通过。
- 原生回归使用快照的 `App/Tests/run-launcher-window-regression.py`，设置 `ASKY_DERIVED_DATA=/Users/niallyoung/orca/Asky/build/DerivedData-search-performance-final`。本地快照 runner 增加 `-whole-module-optimization` 减少重复编译，未修改项目 runner。
- `--filter-search`：亮暗模式均通过，覆盖 200 项首尾导航、实际末行与底部留白、20 次快速输入后的最新查询、迟到批次隔离、分类命令和原生编辑。键盘专项窗口忽略鼠标事件，避免用户指针干扰断言；退格通过窗口键盘事件分发，不直接调用依赖 NSApp.currentEvent 的输入代理。
- `--compact-results`：亮暗模式均通过，检查 PDF、带扩展名目录、应用图标与单行结果，已查看实际截图。
- `--bottom-clearance`：亮暗模式均通过，覆盖滚轮/精确滚动、输入区滚动、键盘边界与末行留白。
- `--alias-results`：亮暗模式均通过，覆盖跨分组键盘导航、鼠标选择不滚动、目标去重与底部留白。
- `--app-opening`：亮暗模式均通过，原生 Return 先隐藏面板再等待应用启动，旧启动任务等待期间可再次唤起并输入，迟到完成不会清除新会话。
- `--command-entry`：亮暗模式均通过，覆盖所有网页指令的原生 Return、自定义触发词、大小写、查询 URL、空格与退格。快照中的该键盘专项也忽略鼠标输入；产品输入逻辑未变。

5 ms 主循环探针在快速输入夹具中的调度间隔：

| 外观 | P95 | 最大值 |
| --- | --- | --- |
| Aqua | 11.47 ms | 22.95 ms |
| Dark Aqua | 6.85 ms | 23.48 ms |

这是本机 Debug 夹具的一轮调度采样，不是输入到显示延迟或生产环境 P95，也没有修复前后的性能对照。未做长时间 Instruments 分析、云盘/外置盘压力测试或用户物理键盘的连续输入验收。

## 未通过与修正

- 初始占位图使用了未收录的 `app` 名称，原生回归触发断言；改为已有 `app.badge` 后通过。
- 并行源码/构建输入变化曾导致编译失败，之后使用冻结快照顺序编译。旧退格用例直接调用代理，受到无关键盘事件影响；改为实际窗口键盘事件后通过。键盘首尾导航还曾被用户指针改变选择，隔离鼠标后通过；独立鼠标回归仍保留并通过。
- 额外执行完整 `--alias-routing`，在“配置的快捷指令别名必须保持第一项”断言失败。该用例把 `sc` 配为别名，而 `sc` 同时是内置分类入口；本次未改变对应排序。未另跑修复前的完整用例，不能把其失败认定为已确认的历史缺陷；本次没有修改此行为。此前经过的网页指令部分另以 `--command-entry` 完整跑过并通过。

## 文档与指令检查

README：本次不修改，使用方式、依赖和开发入口保持一致；工作区内并行任务的 README 改动保留。

AGENTS.md：unchanged，现有 ToolService 边界和构建/验证命令仍适用，没有新增持久规则。

所有快照、图片、编译产物与本地回归 runner 均沿用已有 `build/` 忽略规则，不进入源码提交。
