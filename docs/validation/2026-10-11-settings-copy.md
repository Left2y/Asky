# 设置列表文案精简

- 删除通用页的主题、终端与剪贴板说明行，以及重复的剪贴板快捷键指引。
- 删除网页关键词列表中的用法副标题、添加表单说明和分组标题的括号说明；保留名称与网址。
- 删除外部 MCP 与权限页的大段常驻说明；保留连接状态、权限状态、操作按钮及错误反馈。
- 别名与快捷指令空状态缩短为“暂无别名”和“暂无快捷指令”。启动器与剪贴板快捷键正常注册时不展示额外状态行，失败提示仍显示。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：通过，166 个测试。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/run-settings-regression.py`：最终运行通过，覆盖全部设置页的浅色与深色原生窗口渲染、页面切换与最小窗口尺寸检查。
- 已查看本轮原生窗口渲染截图：浅色通用、浅色权限、深色网页关键词；说明段落不再占据列表行。截图在被现有 `build/` 规则忽略的目录中。
- 首次回归进程收到 SIGKILL，执行 `codesign --force --sign - build/SettingsRegression.app` 后原生回归通过；最终完整脚本重跑亦通过。没有修改回归脚本。

仅精简展示文案，设置值、工具能力与授权流程不变；未打包或安装 Release。

README: unchanged — 使用方式、开发命令与功能范围不变。
AGENTS.md: unchanged — 未改变开发入口、模块边界或持久协作规则。
