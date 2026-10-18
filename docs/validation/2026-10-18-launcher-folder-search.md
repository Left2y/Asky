# 启动器文件夹内搜索

日期：2026-10-18。

## 行为

- 选中文件搜索结果中的真实文件夹后按 Tab，输入框显示系统文件夹图标及目录名称，保留输入焦点；“更多”菜单提供“搜索文件夹 ⇥”入口。
- 空输入显示直属可见项目；输入文件名匹配直属项目，并通过 Spotlight 补充已索引的子目录结果。单字查询有效，指令样式的文件名按普通文字处理；不读取文档正文。
- 子文件夹支持继续 Tab 进入。Esc 或空输入退格返回上一层；最外层退出恢复原搜索。回车仍沿用打开操作。
- 系统读取由 ToolService 提供；隐藏项及配置的排除目录不会出现在目录搜索结果中；应用包不支持 Tab 进入。查询结果有数量上限，Spotlight 查询最多等待 450ms；取消或退出后丢弃迟到结果。

## 实际执行

- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：262 项通过，覆盖 13 个测试目标。
- `python3 App/Tests/check-localization.py`：通过，中英文键及格式参数一致。
- 新增 `python3 App/Tests/run-launcher-window-regression.py --folders` 原生检查。最终通过运行使用 `build/FolderDerivedData` 中冻结的 Debug 依赖和 `build/FolderSourceSnapshot` 源码快照，避免并行任务改写编译输入；快照运行脚本为 `build/run-folder-snapshot.py`，沿用正式脚本的同一检查。首次针对共享产物的执行曾受到并行写入影响，不计为通过。
- 原生检查在 Aqua / Dark Aqua 均通过：真实 Tab 按键与焦点保留、空目录输入的直属列表、单字匹配、字面指令文件名、子目录进入、Esc、空输入退格、无结果状态、原查询恢复、迟到结果丢弃、删除后的文件夹不可进入、应用包保护、隐藏项与排除目录过滤、面板状态清理。
- 真实 Spotlight 检索在 `App` 目录内找到子目录中的 `LauncherModel.swift`；临时测试目录无需 Spotlight 索引也能浏览和匹配直属文件。
- 已查看实际窗口截图：`build/folder-NSAppearanceNameAqua.png` 与 `build/folder-NSAppearanceNameDarkAqua.png`。文件夹图标和名称位于输入框左侧，结果与操作栏沿用启动器布局。

## 边界

子目录文件名搜索依赖 Spotlight 索引与 macOS 访问权限；本次未测试受系统保护目录的授权弹窗，也未执行真实文件打开操作。构建、截图、测试数据与冻结快照均位于已忽略的 `build/`，不纳入提交。

## “更多”菜单调整

- “搜索文件夹 ⇥”移入“更多”菜单，移除底部独立按钮，Tab 快捷键保持可用。
- 重新执行 XcodeGen、Debug 构建、262 项核心测试及本地化检查，均通过。
- 扩展原生目录回归，检查“更多”中存在该操作，并通过选中菜单项执行后确认菜单关闭、目录范围进入；Aqua / Dark Aqua 均通过。最终检查使用已编译的冻结回归程序重跑；前一次运行受其他输入影响，不计为通过。
- 已查看 `build/folder-more-NSAppearanceNameAqua.png` 和 `build/folder-more-NSAppearanceNameDarkAqua.png`，确认菜单项与 ⇥ 提示正常，底部仅保留原有打开、访达和更多操作。
