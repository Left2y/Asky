# 横向汇率卡片

## 行为

- 汇率结果改为横向双卡片：左侧输入币种和金额，右侧换算币种和金额，中间静态兑换符号。
- 沿用 launcher 的文字、图标、背景 token 与 16 pt 卡片圆角。
- 单币种外币输入默认换算人民币；人民币输入默认换算美元；显式币种对按输入计算。
- 不再展示多币种列表，不提供复制、选择、悬停或兑换按钮。不可用原因仍显示。
- 计算器的回车复制行为保留。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/run-launcher-calculation-regression.py` 编译成功，首次运行因原生输入焦点干扰在 calculator completion 断言失败。随后直接重跑同一 `build/launcher-calculation-regression`，浅色与深色全部通过。
- 原生测试验证：单一币种对、输入金额及人民币结果、无复制 action、上下键不改变选择、反向换算、取消异步结果、显式币种对。
- 已查看最新 `build/currency-NSAppearanceNameAqua.png` 与 `build/currency-NSAppearanceNameDarkAqua.png`：两张卡片横向排列，无结果行或选择高亮。
- 截图来自实际启动的测试 LauncherPanel 的内容截图；未安装或打包 release。

## 完成检查

- README: updated，中英文同步横向卡片与无复制操作行为。
- AGENTS.md: unchanged，系统读写仍经过 ToolService，开发命令与架构边界未变。
- 测试和截图沿用 `.gitignore` 现有 `build/` 规则。
- 未提交：本次修改依赖工作区已有未提交汇率代码和未跟踪测试，无法构成独立完整提交；保留原索引和其他修改。
