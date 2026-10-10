# 剪贴板外侧点击关闭

- 移除顶部关闭按钮，保留图钉。
- 面板显示时监听本应用及其他应用的左、右、中键点击；未置顶时点击面板和完整预览之外关闭，并让原点击继续送达目标。
- 关闭时移除监听器。置顶和 Escape 行为保留。

实际检查：

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：142 tests / 28 suites 通过。初次未指定 DEVELOPER_DIR 时缺少 Testing 模块，重跑通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：通过。首次因另一个构建持有 build.db 锁失败，重跑通过。
- `python3 App/Tests/run-clipboard-regression.py --preview`：未通过，已有脚本引用不存在的 ClipboardScroll，未修改该脚本。
- 新 Debug App 已重启；computer-use 的默认剪贴板快捷键未打开窗口，原生视觉与实际外侧点击未验收。

README 中英文同步了关闭方式。AGENTS.md 无新增命令、架构或边界变化，保持不变。生成工程和 build 产物沿用现有忽略规则。
