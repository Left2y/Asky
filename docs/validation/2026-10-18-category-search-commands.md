# 分类搜索命令入口

日期：2026-10-18。

## 行为

- 现有应用、文件、快捷方式、快捷指令分类分别新增 `app`、`file`、`ql`、`sc` 搜索指令，仍复用原分类查询与最多 200 条结果，不另建页面。
- 普通输入中精确输入触发词，命令置顶，回车进入空查询分类；输入触发词后按空格或粘贴 `file report` 直接进入分类并保留正文查询。也可按“搜索文件”等中文或当前语言的指令名称查找命令。
- 四条指令加入“设置 › 指令”，复用修改、保存、恢复默认和冲突检查；自定义后默认词不再作为入口。
- 分类模式输入框、命令结果和设置项复用 LauncherFunctionIcon，使用已有 MingCute 图形、五色底板与 5pt 普通圆角，AI 图不变。
- Esc 返回普通搜索并保留查询（普通搜索继续按原规则解析网页等命令）；分类空输入退格退出。分类内指令样式文本按普通查询处理；目录导航与浏览器模式内不识别分类前缀。
- 保留原筛选按钮，可继续用鼠标进入相同分类模式。

## 实际执行

- `xcodegen generate` 与 README 的 Debug `xcodebuild` 命令：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：267 项通过，13 个测试目标。
- `python3 App/Tests/check-localization.py`：通过，139 个 Swift 源文件，中英文键与格式参数一致。
- `python3 App/Tests/run-launcher-window-regression.py --filter-search`：通过。Aqua / Dark Aqua 均验证四类默认/自定义指令、大小写匹配、按名称发现、回车与空格入口、分类内字面查询、Esc/空退格退出、触发词冲突检查；同时保留 8 → 200 → 8、200 项滚动和迟到批次隔离检查。
- `python3 App/Tests/run-settings-regression.py --website-commands`：通过，动态遍历全部 8 条搜索指令，验证默认/自定义触发词、精确置顶、回车/空格入口、退格退出、不提前提交 AI；既有网页指令启停、配置持久化、冲突与迁移检查通过。
- `codesign --verify --deep --strict --verbose=1 build/DerivedData/Build/Products/Debug/Asky.app`：通过。
- `git diff --check`：通过。
- 原生 NSTextField 的文字变化回调实测 `file report` 立即进入文件分类，field editor 只保留 `report`；原生 deleteBackward 回调退出空分类并同步编辑器。
- 已查看浅色与深色实际窗口截图 `build/category-search-NSAppearanceNameAqua.png`、`build/category-search-NSAppearanceNameDarkAqua.png`，输入框显示共用的橙色文件夹入口图标，第 200 条结果可见。

## 文档与产物

README 中英文同步触发词和退出方式，PRD 同步分类命令交互。AGENTS.md 维护检查不需要新增规则；图标和系统访问继续遵守既有边界。构建、原生回归、截图、临时数据和日志沿用已忽略的 `build/`，不纳入提交。
