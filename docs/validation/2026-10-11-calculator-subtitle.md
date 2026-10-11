# 移除计算结果的回车复制说明

日期：2026-10-11

计算器条目副标题只保留输入算式，例如 `12-1`，移除 `· ↩ 复制`。计算数值与 `.copy` 动作不变。

已执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`，全部测试套件通过；Asky Debug `xcodebuild` 结果为 BUILD SUCCEEDED。

README: unchanged；仅移除重复说明，功能与使用方法不变。AGENTS.md: unchanged；没有新增开发规范。提交仅包含 IntentRouter 的计算器副标题一行及本记录，其他工作区修改保留。临时原生预览及截图复用既有 `build/` 忽略规则。

原生预览：为避免输入法引起的空查询回写，临时入口直接设置查询并禁用输入框 delegate；已通过计算器数值、复制动作和补全检查，并人工查看本次生成的 Aqua 窗口截图，副标题仅为 `1+1`。随后涉及 delegate 的汇率键盘选择检查失败，因此没有将整个原生回归记为通过。临时入口未写入项目源码。
