# 汇率与计算器补交验证

日期：2026-10-11

本次补交此前留在工作区的完整汇率与计算器改动：单币种查询、多币种同快照换算、ToolService 入口、横向卡片、下方其他币种列表、计算器卡片及只读输入补全。保留语言设置、原生粘贴菜单、剪贴板和其他功能的未提交修改。

从 HEAD 与任务暂存内容导出独立临时目录，所有下列验证均在该目录运行，不依赖工作区其他未提交代码：

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：退出码 0，全部测试通过。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `python3 App/Tests/run-launcher-calculation-regression.py`：浅色与深色全部通过；实际创建原生 LauncherPanel，覆盖补全、长算式、大数、币种卡片与其他币种数量、无复制动作、无键盘选择、人民币反向换算、显式币种对与旧查询取消。
- `git diff --cached --check`：通过。

本次未额外人工检查截图、鼠标滚动或桌面玻璃合成；未打包 Release、未安装、未推送。较早记录中的“未提交”是各次调整结束时的历史状态，此次将相关依赖与验证记录一起补交。

README: updated，提交中包含中英文使用行为和原生回归命令；语言设置等无关文档改动保留。
AGENTS.md: unchanged，既有模块、ToolService 边界和构建约定未变。
产物沿用现有 `.gitignore` 中的 `build/` 规则，无新增忽略规则。
