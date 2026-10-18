# 自有工具入口图标标准

## 实现

- `LauncherFunctionIcon.Kind` 集中声明链接、书签、换算、标签页、AI 搜索、计算器、退出的 MingCute 图形与纯色背景；不再依赖预合成 PNG，也不进行逐图缩放与偏移。
- 统一 16 pt 白色图形、20 pt 纯色底板、4 pt 普通圆角、24 pt 外层图标槽。搜索结果、输入模式和指令设置共用组件。
- 从既有固定上游版本 `ca98bb55513a22ff0dab713aaf7870b512944653` 导入 power、web；图标清单与 Swift 映射同步。
- 规则写入设计系统、双语 README 与 App/AGENTS.md。真实应用、网站品牌、国旗、内容缩略图保留原始来源。

## 实际验证

- `python3 scripts/import-mingcute-icons.py /tmp/asky-mingcute-upstream`：通过，导入版本匹配清单。
- `xcodegen generate`：通过。
- README 中 Debug `xcodebuild` 命令：通过，日志 `/tmp/asky-tool-icons-build.log`。
- 使用实际 `LauncherFunctionIcon`、`MingCute` 及新构建的 Assets.car，在原生 NSWindow 中检查全部七类工具的浅色与深色渲染。预览程序运行通过，截图为 `build/tool-icons-NSAppearanceNameAqua.png` 和 `build/tool-icons-NSAppearanceNameDarkAqua.png`。初次预览缺少 bundle Info.plist 导致资源查找失败，补齐预览 bundle 信息后通过。未替换已安装应用。
- KulaCore `swift test`：未全量通过。AgentHostTests 的 `unreachableModelFailsAndProcessIsGone` 仍有两项断言失败（`.running` 状态与 `runningPID`），与前一轮运行时环境问题相同。日志 `/tmp/asky-tool-icons-tests.log`。
- `git diff --check`：通过。预览与构建产物复用现有 `build/` 忽略规则。

README: updated，同步中英文图标来源与几何标准。

AGENTS.md: updated，在 App 范围明确复用组件和规范入口。
