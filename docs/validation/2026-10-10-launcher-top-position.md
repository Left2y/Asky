# 搜索浮窗顶部位置调整

- 浮窗可见外壳顶部从鼠标所在屏幕 visibleFrame 高度的 22% 改为 12%，保持水平居中。位置补偿仍包含透明阴影边距。
- 最大列表高度使用同一个顶部比例计算，底部保留 24 pt，并继续受 launcherMaxHeight 限制；结果增减保持顶部固定。
- README 中英文同步位置说明。

## 实际验证

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：128 项测试、27 个 suite 通过。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `git diff --check`：通过。
- 未进行实际浮窗截图验收；构建不会替换运行中的旧进程，需重启后查看。

AGENTS.md 未改动：开发命令、模块边界与持久指引无变化。构建输出与生成工程沿用现有忽略规则。原有输入框、回归检查和验收文档改动保留，不纳入本次提交。
