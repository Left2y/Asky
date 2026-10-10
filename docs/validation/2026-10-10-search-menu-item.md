# 搜索菜单项样式验证

日期：2026-10-10

## 设计与实现

- 来源：[Figma Spotlight Item 38:461](https://www.figma.com/design/tmVnTyCb2sz5egNQ7We9Sw/Asky?node-id=38-461)。读取了完整设计上下文及四种变体截图。
- `App/Sources/LauncherView.swift`：694 × 50 pt 结果行，16 pt 水平内边距，32 pt 动态目标图标，12 pt 图文间距，16 pt 行圆角。
- 标题 14 pt / 22 pt 行高；路径 12 pt / 20 pt 行高。关键词行保留单行布局，关键词标签为 14 pt / 22 pt，水平内边距 6 pt，12 pt 圆角，使用 `backgroundNeutral` 填充。
- 悬停、键盘选中及文字继续复用语义颜色。图标继续经 ToolService 读取实际目标，不把 Figma 中的示例 Safari 图片用于所有结果。
- 同步结果列表高度计算和水平内边距。没有修改查询、关键词配置或执行逻辑。

## 实际执行

1. 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：127 tests / 27 suites 通过。
2. `xcodegen generate`：成功。
3. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：`BUILD SUCCEEDED`。
4. 用临时 SwiftUI ImageRenderer harness 渲染实际 ResultRow 视图代码，检查单行标签、双行路径、默认和悬停四种状态，以及长标题/长路径选中行。浅色与深色均生成 2× 图片并逐一查看；长文本保持一行且在尾部截断，图标、标签和背景位置正常。
   - 本地图片：`build/menu-item-review/light.png`、`build/menu-item-review/dark.png`。
   - harness 仅在复制到临时文件的视图声明中开放 hovering 初值，以设置悬停状态；生产视图保持真实 onHover。
   - 产物由现有 `build/` 忽略规则覆盖。

## 验证边界

组件渲染不是实际透明 NSPanel 的合成截图。本次未启动或重启应用，未执行真实浮窗键盘/鼠标端到端验证。没有新增动画，减少动态效果行为未修改；现有减少透明度开关所在的浮窗外壳未修改。

README 已同步中英文菜单项尺寸及设计来源；AGENTS.md 检查无新增命令、模块或系统操作边界，保持不变。
