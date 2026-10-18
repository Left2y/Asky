# 普通文件搜索漏掉精确名称文件夹

日期：2026-10-18。

## 复现与原因

- 系统 Spotlight 元数据查询可找到 `/Users/niallyoung/orca`，说明该目录已经索引。
- 修改前，真实 `SpotlightProvider.search("orca", limit: 8)` 连续三次只返回 `2026-10-12-orca-cli-skill.md`，漏掉 `orca` 文件夹。
- 原实现先按内容修改时间排序，截取 `limit * 3`（普通入口为 24）条，再过滤 Library 和隐藏目录。最近的 Orca 缓存占据候选名额，旧文件夹在过滤、相关度排序之前即被丢弃。即使剩余候选都有效，名称精确匹配也可能被大量较新的部分匹配挤掉。

## 修复

- 将普通文件元数据读取移入 ToolService，Search provider 仅转发已配置的范围、排除规则、数量与超时；Search 声明对 ToolService 的单向依赖。
- 对已收集的 Spotlight 快照先过滤隐藏项、Library、排除目录，再以精确名称、名称前缀、词段前缀、包含关系排序。相同匹配等级沿用修改时间顺序。
- 遍历快照时仅保留最优的有限数量结果，不在过滤前截断。保持原有 450ms 查询等待上限，不读取文件正文，不建立自有文件索引。
- 排除规则支持目录名称与绝对路径（含 `~`），绝对路径按目录边界匹配，避免排除 `private` 时误伤 `private-copy`。
- 修改后真实 provider 连续三次均返回 `orca` 文件夹在前、上述 Markdown 在后。

## 实际执行

- `xcodegen generate`：通过。
- README 中 Debug `xcodebuild` 命令：通过。Xcode 输出现有 iOS CoreDevice / Simulator 插件环境提示，macOS 构建成功。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：267 项通过，13 个测试目标；新增 5 项覆盖缓存挤占、名称排序、排除目录边界、去重、空范围和取消。
- `python3 App/Tests/check-localization.py`：通过，139 个 Swift 源文件。
- `python3 App/Tests/run-launcher-window-regression.py --file-search`：通过。使用真实 provider 和 LauncherModel，在 Aqua / Dark Aqua 两种外观都找到当前 checkout 上级的已索引 `orca` 文件夹，且可进入文件夹搜索；已查看两张实际截图，文件夹显示于文件结果第一项。
- 第一次窗口检查被外部键盘输入干扰，查询变为其他文字，该次失败不计为通过。最终检查在窗口显示后交还键盘焦点，重新运行通过。
- `git diff --check`：通过。
- README 同步中英文文件排序说明与实际执行的 `--file-search` 检查入口；AGENTS.md 经维护检查无需变更，未新增持久开发规则。
- 产物、探针、构建日志和截图放在已有 `.gitignore` 忽略的 `build/` 下。

## 能力边界

本次修复普通文件搜索召回；应用搜索保持原有来源。原生 Spotlight 截图中的系统菜单项并非当前 Asky 的搜索源，此次没有新增菜单项搜索。文件召回仍取决于配置范围、Spotlight 索引和系统访问权限；此次未检验受保护目录授权流程。
