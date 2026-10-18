# 移除自定义网站指令遗留代码

按用户要求移除未开放的自定义网站指令能力，保留 14 个内置网站、指令启停和触发词修改。模拟图中的“我的网站”并非正式功能。

## 变更

- 删除 KeywordRegistry 的增删改接口、相关错误类型、可序列化支持及旧自定义网站预设迁移。
- 删除任意指令集合注入接口；注册表仅接受内置指令禁用集合及触发词映射，未知预设 ID 不会生成新网站。
- KeywordCommand 只允许在定义文件内构造，网站名称、地址和触发词不可变。
- AppModel 使用收窄后的注册表；旧配置回归通过原始数据夹具验证，不再依赖已删除的自定义网站 API。
- 删除旧自定义网站测试，保留内置查询参数编码测试，验证改触发词不改变目标网址、禁用指令失效及未知指令不能新增网站。
- README 中英同步说明只提供内置网站预设。

## 实际验证

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，共 260 个 Swift Testing 测试。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --website-commands`：通过，验证旧网站配置不能覆盖内置预设、启停与持久化、触发词修改与冲突、路由与品牌身份。
- 全量设置回归 `python3 App/Tests/run-settings-regression.py`：失败于 `SettingsRegression.swift` 的 MCP 工具复选框布局断言；未改动该检查或相关控件。
- 可视化搜索指令回归 `build/SettingsRegression.app/Contents/MacOS/SettingsRegression --search-commands`：失败于执行选中结果后进入 scope 的断言；未将此项记为通过。为本次注册表清理添加 `--website-commands` 提前退出点，执行已有网站与触发词行为断言，不运行可视化检查。
- 未进行新的手动窗口视觉检查：正式 UI 布局与图标没有修改。

本地日志为 `build/remove-custom-websites-{core,build,settings,commands,focused}.log`，复用现有 build/ 忽略规则。AGENTS.md 无需修改：没有新架构边界或开发入口。保留此前未提交的图标模拟窗口验证记录。
