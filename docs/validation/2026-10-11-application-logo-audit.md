# 应用 Logo 排查与修复

## 修改

- 启动器普通快捷指令结果原来直接显示 `square.stack.3d.up`，现在使用系统快捷指令应用图标；快捷指令别名复用同一来源。
- Chrome 标签结果原来显示地球符号，现在使用 Chrome 应用图标。
- AI 工具记录的日历、提醒事项、备忘录、通讯录、信息、Chrome、快捷指令与个人记忆使用共享 DataSourceIcon。原生应用图标仍通过 ToolService 获取，个人记忆使用 AskyLogo。
- 数据来源设置复用同一组件；应用不存在时按来源显示有含义的后备符号。
- 检查应用/文件结果、书签默认浏览器、书签搜索入口、内置网页指令、可选终端、别名设置、关于页与菜单栏：这些已有文件/应用/品牌资源。筛选菜单、设置导航、权限类别和操作按钮属于功能符号，无需更换品牌图标。

## 实际验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：通过。
- `xcodegen generate` 与 README 中的 Debug xcodebuild 命令：通过。
- 本地临时原生检查程序编译全部 App 源码并链接新 Debug 产物，以隔离存储和模拟搜索结果运行实际 LauncherController：浅色、深色外观均完成，快捷指令和 Chrome 结果均存在。
- 系统应用图标解析检查：日历、提醒事项、备忘录、通讯录、Chrome、快捷指令、信息、地图、终端全部返回图标。
- 使用 computer-use 捕获并目视检查实际窗口：快捷指令紫色 Logo 与 Chrome Logo 正常显示。截图及临时程序保存在已忽略的 build 目录。
- 首次临时窗口检查因查询在窗口初始化前设置而没有结果，未计为通过；等待窗口初始化后设置查询，再次运行成功。
- AI 工具记录已通过 App 编译，未逐项触发实际系统工具，也未发送模型请求。

README: unchanged — 图标显示修复不改变既有用法、构建命令或能力说明。

AGENTS.md: unchanged — 未引入新的模块边界或开发约定。
