# Finder 操作移至左侧操作区

文件和 App 结果在“打开”后直接显示“在访达中显示”，使用已有玻璃按钮与配置的快捷键；更多菜单移除重复入口，保留拷贝和复制路径。其他结果维持原动作。

## 实际验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过，日志 `build/finder-action-build.log`。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，日志 `build/finder-action-core-tests.log`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --action-bar`：未全量通过。初次编译发现原有测试直接修改 private(set) 结果，改为已有测试 Provider 驱动后可运行；文件动作分组、菜单导航与复制路径检查已执行，随后在“Cmd C must preserve selected search text copying”断言失败。
- 实际浅色窗口截图 `build/launcher-actions-NSAppearanceNameAqua-closed.png` 已查看：左侧两个操作并排、文字和快捷键完整，右侧保留更多。深色与 App 截图未完成验收。
- 为排除复制检查的临时定向运行仍发生焦点路由失败，直接重跑还遇到数组越界，临时跳过选项已移除；未将这些检查记为通过。

## 范围与工作区

工作区原有文件拷贝、按钮样式、翻译及 README 改动，本次保留。回归文件在执行过程中仍有并发修改；本次与原有改动交叠，不自动提交混合内容。构建日志与截图复用 `build/` 忽略规则。

README 中英文及设计系统已同步位置说明。AGENTS.md 不变：未改变架构边界、模块或开发命令。
