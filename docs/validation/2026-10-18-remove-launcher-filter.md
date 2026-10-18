# 移除启动器重复筛选入口

日期：2026-10-18。

## 行为与实现

- 启动器空输入右侧仅保留原有固定按钮；输入文字或进入命令模式后仍隐藏固定按钮，让出输入空间。
- 移除来源筛选按钮、来源菜单、菜单专用 NSPanel、菜单动画以及模型的展示状态。其他模块的筛选功能不受影响。
- 文件、应用、快捷方式和快捷指令继续通过 `file `、`app `、`ql `、`sc ` 进入原有最多 200 条的分类模式。也可搜索命令名称后回车进入；Esc 退出，空输入退格退出。
- 各搜索模式互斥；当前模式内的其他触发词保持字面查询，退出后才能进入另一模式。沿用上一轮已验证的前缀解析与输入状态实现。
- README 中英文和 PRD 同步命令作为分类入口；设计系统同步单个固定按钮；AGENTS.md 仅移除已不存在的启动器筛选按钮描述，保留所有玻璃、阴影和布局约束。

## 实际执行

- `xcodegen generate` 和 README 的 Debug `xcodebuild` 命令：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：267 项通过，13 个测试目标。
- `python3 App/Tests/check-localization.py`：通过，139 个 Swift 源文件。
- `python3 App/Tests/run-launcher-window-regression.py --accessories`：Aqua / Dark Aqua 均通过，验证单窗口 640×52 pt 外壳、固定与失焦行为、输入/清空后的文字宽度和位置、分类结果隔离、Esc 及重复打开/关闭。删除了已移除菜单的回归及录屏分支。
- 已查看 `build/launcher-pin-only-NSAppearanceNameAqua.png` 和 `build/launcher-pin-only-NSAppearanceNameDarkAqua.png`，两种外观的空输入窗口右侧都只有固定按钮。
- `codesign --verify --deep --strict --verbose=1 build/DerivedData/Build/Products/Debug/Asky.app`：通过。
- `git diff --check`：通过。
- 静态检查确认启动器源码不再引用来源菜单的展示状态、NSPanel、动画或筛选按钮标识。

## 产物

构建、截图、原生回归临时数据和日志继续位于已有 `.gitignore` 覆盖的 `build/`，不纳入提交。
