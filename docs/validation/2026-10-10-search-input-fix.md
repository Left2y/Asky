# 指令输入与退格修复

用户现场反馈：输入 go 后图标已出现，但文本框仍留有 go，需要第二个空格；退格不能退出指令模式。

## 修复

- LauncherInputState 将已消费的指令和可见正文分开保存；第一次空格进入模式，正文立即为空，后续输入仅修改正文。
- 使用原生 NSTextField 的活动 field editor；文本变化的同一次 delegate 回调同步转换后的正文和光标，避免 SwiftUI TextField 延迟回写已消费的关键词。
- 在原生编辑命令 delegate 处理 deleteBackward：先按原生方式删除正文，正文为空后的下一次退格清除指令。原生文本框保留方向键、Return 与 ⌘Return；输入法有 marked text 时不干预组词。
- Escape 继续退出指令，reset 清除指令和正文。其余设计布局不在本次修复范围内。

## 实际验证

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：124 tests / 25 suites 通过。其中新增 4 项输入状态回归，覆盖单空格消费、正文保留空格、空正文退格、退出指令与重置。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：`BUILD SUCCEEDED`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/LauncherSearchField.swift App/Tests/LauncherSearchFieldRegression.swift -o build/launcher-input-regression && build/launcher-input-regression`：`LauncherSearchField native regression checks passed`。使用实际 NSWindow、NSTextField 与活动 NSTextView field editor，验证一个空格后文本与光标立即清空，后续正文没有 go 前缀，空输入退格 delegate 清除指令后能再次输入 Safari。
- `git diff --check`：通过。

原生回归检查直接测试编辑器和 delegate，不等于真实键盘输入或桌面截图验收；未验证用户实际 App 的现场重试，也未执行网络搜索或 AI 提交。最终构建需重启正在运行的 App 后体验。

构建及回归程序沿用现有 build/ 忽略规则。README 中英文增加实际原生回归命令，AGENTS.md 无新的稳定约束。工作区同时出现的链接、书签、搜索列表留白及设置变更不属于本次提交。
