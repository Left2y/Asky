# 删除模型服务提示行

日期：2026-10-13。

删除模型设置中的“选择服务商后，地址和模型会自动填好，只需输入 API Key”提示视图及中英文资源。

实际执行：
- `xcodegen generate` 通过。
- README 声明的 Debug `xcodebuild` 通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 通过。
- 两个 Localizable.strings 的 `plutil -lint` 通过。
- `git diff --check` 通过。

原生界面未完成验收：新构建应用已启动（PID 89883，build/DerivedData/Build/Products/Debug/Asky.app，版本 0.1.0），computer-use 未找到可访问窗口。随后运行 `App/Tests/run-settings-regression.py`，因并行构建期间共享 Theme.o 被修改而编译失败；没有将既有截图记为本次证据。

README: unchanged — 删除辅助文案不改变配置步骤或开发命令。
AGENTS.md: unchanged — 未改变模块边界或持久开发规则。

Git：修改位置属于任务开始前已经存在的未提交模型预设改动，提示行尚未进入 HEAD；无法单独提交删除而不包含既有功能改动，故未提交。保留既有工作区改动。构建产物复用 build/ 忽略规则。
