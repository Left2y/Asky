# 设置拆分与文件夹退格偏好

## 变更

- 通用保留启动、主题、玻璃与语言；文件搜索范围和排除目录移至“搜索与导航”，剪贴板设置移至独立页面。
- “搜索与导航 › 文件夹导航”提供“返回上一层”（默认）与“退出文件夹导航”。后者在空输入退格时清空所有文件夹层级与查询，保持启动器显示。Esc 仍逐层返回；有文字时正常删除文字。
- 新分类使用现有 MingCute search / clipboard SVG，资源映射同步到 scripts/mingcute-icons.json。
- 新偏好缺失时默认返回上一层；选择随 preferences 持久化。

## 已运行检查

- `xcodegen generate`：通过。
- README 中 Debug `xcodebuild` 命令：通过，日志 `build/settings-navigation-build.log`。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：267 项 Swift Testing 测试通过。首次未指定 Xcode 的运行因 Command Line Tools 缺少 Testing 模块失败；指定后通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --navigation-settings -AppleLanguages '(zh-Hans)'`：通过。三个页面浅色/深色窗口布局与标题、原生 NSPopUpButton 切换、保存后重新载入均通过。已查看通用、搜索与导航、剪贴板截图。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --folders`：最终通过；覆盖浅色/深色、Tab 嵌套、两种空输入退格行为、非空输入、旧配置默认值和偏好重启保存，日志 `build/navigation-folders-final.log`。
- 相同设置回归使用 `-AppleLanguages '(en)'`：通过；已查看英文搜索与导航页面截图。
- `git diff --check`：通过。

## 验证边界

完整设置回归首次被既有中文标题断言触发，已将该断言改为本地化标题；中文运行随后停在既有 MCP 复选框布局断言，未宣称完整设置套件通过。本次三个页面使用独立回归参数验证。文件夹首次运行受到外部键盘输入影响，新增用例的下一轮另修正了异步搜索结果等待；最终独立运行通过。

构建、测试二进制、截图与日志均由现有 build/ 忽略规则覆盖。

## 文档维护

README 中英文同步了设置入口、退格选项与独立回归命令；PRD 同步默认及可选导航行为。AGENTS.md unchanged：无新增架构边界或持久开发规则。
