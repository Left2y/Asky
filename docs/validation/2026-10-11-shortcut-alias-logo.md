# 快捷操作别名原生图标

别名仅有应用与快捷操作两类：应用读取目标应用图标；快捷操作读取 `/System/Applications/Shortcuts.app` 原生图标，与别名设置页一致。

实际验证：KulaCore `swift test`、`xcodegen generate`、README Asky Debug `xcodebuild` 通过。复用临时别名原生窗口 harness，浅色与深色执行通过，截图确认快捷操作显示紫色 Shortcuts logo。首次窗口检查受到外部键盘输入干扰导致查询变化，增加窗口稳定等待后通过。

日志：`build/shortcut-alias-icon-build.log`、`build/shortcut-alias-icon-regression.log`。截图：`build/alias-icon-sc-NSAppearanceNameAqua.png`、`build/alias-icon-sc-NSAppearanceNameDarkAqua.png`。沿用 build/ 忽略规则；未打包或安装 Release。

README 与 AGENTS.md 无需改变：现有图标修正不影响用法、命令或模块边界。
