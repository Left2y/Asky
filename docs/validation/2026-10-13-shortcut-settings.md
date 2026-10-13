# 快捷键设置统一列表验证

日期：2026-10-13。

## 改动

- 启动器、剪贴板、AI 对话、在访达中显示、复制文件路径统一为一个无重复小标题的五行列表，逐项录制和恢复默认。
- 后两项是启动器内所选文件或应用的操作，默认分别为 ⌘F、⌥⌘C；没有新增全局系统操作。
- 新设置字段从旧偏好中缺失时补默认值；面板和输入框使用同一份当前偏好匹配键盘事件。
- 本地操作拒绝与已有全局快捷键、另一本地操作、⌘逗号和 ⌘Return 重复的组合；全局设置也拒绝与本地操作重复。

## 已运行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。Xcode 输出 CoreDevice/模拟器版本警告，不影响 macOS 构建结果。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：245 个 Swift Testing 测试通过。
- 临时 Swift 检查使用源码中的 LauncherActionShortcut：自定义组合匹配、额外修饰键拒绝、错误键拒绝、⌘C 不误触复制路径、Caps Lock 不影响匹配、Codable 往返均通过。
- 实际运行 `build/DerivedData/Build/Products/Debug/Asky.app/Contents/MacOS/Asky`，PID 2065，版本 0.1.0 (1)。实际深色设置窗口截图及可访问性树确认五行、行内恢复默认、无逐项标题和作用范围说明；点击“在访达中显示”进入录制状态。

## 未验证

录制后发送组合键受到 computer-use 的窗口焦点校验阻拦（恢复窗口后仍报告 window_not_focused），没有把这一步记为成功。修改后的真实访达/复制动作、跨重启偏好持久化及浅色布局未完成实测。

## 文档门禁

README 中英文同步说明五项快捷键和本地操作范围。AGENTS.md 保持不变：没有新增模块、命令或系统执行边界。
