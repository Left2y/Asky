# AI 窗口顶部图标按钮悬停反馈

日期：2026-10-10。

- 历史 / 返回、新对话、置顶、关闭共用的 `AgentHeaderButtonStyle` 增加圆形悬停背景，使用当前外观的 `kInteractionHover`，叠加在玻璃背景上。
- 保留 32 pt 尺寸、图标、玻璃、阴影和原有操作；按下也显示背景并保留透明度反馈。禁用按钮不高亮，命中区域为圆形。

## 实际检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：140 tests / 28 suites 通过。首次未指定完整 Xcode 时因 `no such module 'Testing'` 失败，切换完整 Xcode 后通过。
- `xcodegen generate` 成功。
- README 中的 Debug `xcodebuild` 命令成功；现有 CoreSimulator 版本警告不影响 macOS 构建。
- `git diff --check` 通过。

本轮未重启正在运行的 App，未完成实际鼠标悬停及浅色 / 深色视觉验收。构建不会更新已有进程。

README 与 AGENTS.md 无需修改：这是既有图标按钮的反馈修复，没有改变使用方法、开发命令或模块边界。构建产物复用现有 `build/` 和 `KulaHere.xcodeproj/` 忽略规则。
