# 备忘录授权文件夹添加反馈

## 原因与修复

原表单的账户和文件夹为空时，添加动作直接返回，没有禁用状态或填写说明。提示文字并不是已填写的值。

- 去除账户和文件夹名称首尾空白。
- 任一项为空或该账户/文件夹组合已经授权时禁用添加。
- 显示填写说明和重复提示；保留原有授权列表配置流程，不新增系统访问。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：通过。
- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过。
- `python3 App/Tests/run-settings-regression.py`：通过，生成原生浅色/深色窗口快照，人工查看浅色数据来源滚动快照，填写说明正常显示，空输入时按钮置灰。
- `plutil -lint` 两种语言的 Localizable.strings：通过。
- 临时 SettingsRegression 窗口的辅助功能树确认空输入、只设置账户时按钮禁用。辅助功能 set-value 并不能证明 SwiftUI 输入绑定完成，因此未将完整添加点击链路记为通过。

未安装或打包 Release；未验证真实 Notes 文件夹访问与系统自动化权限。

## 文档维护

README: unchanged — 修复已有表单的无反馈问题，开发命令、权限与既有使用流程保持一致。
AGENTS.md: unchanged — 未改变模块边界、子项目或开发流程。

测试产物沿用 `.gitignore` 中的 `build/` 规则。提交仅包含本次设置表单、翻译与验证记录，保留工作区原有及并发的其他改动。
