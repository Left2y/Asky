# 人民币卡片与其他币种列表

- 恢复完整多币种换算请求。
- 上方保留输入币种与人民币的横向双卡片；其他币种以原来的旗帜、金额、币种列表显示在下方，不重复显示卡片目标币种。
- 下方列表沿用既有 ScrollView 和行样式，按剩余窗口高度显示；无复制、选择或悬停状态。
- 显式币种对只显示指定换算；人民币输入沿用美元主卡片、其他币种列表。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/run-launcher-calculation-regression.py --currency-only`：通过。此模式跳过计算器焦点测试，释放输入焦点，只验证汇率查询、全部币种数量、无复制动作、无键盘选择、取消、反向换算和显式币种对。
- 默认测试模式两次受输入焦点干扰失败，不能记为通过。
- 查看最新浅色与深色原生 LauncherPanel 内容截图：人民币卡片下方可见欧元、日元、英镑、港元、韩元、新加坡元、澳元与加元，无重复人民币行和选中高亮。未单独模拟鼠标滚动，也未检查安装版本。

## 完成检查

- README: updated，中文与英文补充其他币种在卡片下方保留列表；PRD 同步。
- AGENTS.md: unchanged，开发命令和系统读写边界未改变。
- 产物与截图使用已有 `.gitignore` 的 `build/` 规则。
- 未提交：本次代码依赖工作区已有未提交的汇率实现和未跟踪测试，无法隔离成完整提交；保留用户索引和其他修改。本次未安装或打包。
