# 启动器别名结果修复

## 问题与变更

普通搜索命中自定义别名时，通用搜索引擎入口也会被加入结果，自定义别名被归入「默认搜索」，且同一应用/快捷指令可能被 Provider 再列一次。鼠标悬停仅改变背景，没有同步实际选择。

- 全部搜索只保留精确命中的关键词命令，不附带无关搜索引擎；显式关键词搜索和快捷方式筛选保留。
- 自定义别名归入「别名匹配」，别名与 Provider 中同一应用/快捷指令目标只显示一次。
- 鼠标悬停同步实际选择，不触发滚动定位；键盘从该项继续导航。行背景统一使用实际选择，避免悬停旧行和键盘新行同时高亮。

## 检查

- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，共 262 项 Swift Testing 测试。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --alias-results`：深浅色原生窗口通过。隔离存储中用 `codex` 别名指向备忘录，Provider 同时返回相同目标及另一个目标；验证去重、无无关搜索引擎、实际指针移动选择第二项、不滚动跳行，以及键盘接续到 AI。
- 使用同一原生回归可执行程序运行 `--alias-routing`：通过，覆盖关键词精确匹配、大小写、迟到批次、快捷指令优先级与带空格关键词输入。
- 观察深浅色截图中的别名与应用分组、底部操作区及结果行；截图位于 `build/launcher-alias-results-NSAppearanceNameAqua.png` 和 `build/launcher-alias-results-NSAppearanceNameDarkAqua.png`。

测试最初因测试脚本强制读取已恢复为系统默认的可选外观而中断，已改为在测试偏好中固定外观并重跑。不修改用户存储，不替换已安装 App；结果验证使用隔离夹具。

README 已补齐双语回归命令。AGENTS.md 无变化：现有开发命令、模块边界和指引适用。
