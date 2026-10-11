# AI 窗口 Pin 按钮点击区域与悬停修复

## 改动

- 将完整 32×32 圆形命中区域放进 Button label，覆盖图标周围的空白区域。
- 标题栏四个同款按钮共用标签构造，保留 20×20 图标与原布局。
- 玻璃背景仅负责绘制，不参与命中；悬停和按压由 ButtonStyle 使用 InteractionHover 提供反馈。

## 实际检查

- `xcodegen generate`：通过。
- Xcode 工具链 `swiftc -frontend -parse App/Sources/AgentView.swift`：通过（仅语法解析，不代表类型检查或构建通过）。
- `git diff --check`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：阻塞，退出码 69，Xcode 许可协议未接受。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：同一许可协议阻塞，退出码 69。

## 未完成的验证

尚未编译或启动修改后的窗口，不能宣称整圈点击、真实悬停和 Pin 状态切换验收通过。接受本机 Xcode 许可后，需要重新运行测试与构建，再检查圆形空白区悬停及点击切换置顶/取消置顶。

README: unchanged — 此修复不改变使用方式、开发命令或产品范围。
AGENTS.md: unchanged — 未改变工程边界或持久开发约定。
