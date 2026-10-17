# 剪贴板历史列表与搜索结果样式对齐

日期：2026-10-17

## 变更

剪贴板列表式的历史行复用 `LauncherLayout` 的 50pt 行高、16pt 行内水平留白、16pt 圆角、零行间距与列表水平留白。图标统一为 32pt，标题为 14pt / 22pt 高，复制时间为 12pt / 20pt 高。选中背景使用搜索结果相同的 `kBackgroundSelected`，鼠标悬停使用 `kInteractionHover`，移除旧的选中描边。保留固定标识、选择、拖放和右键菜单。

## 实际验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts`：通过，覆盖布局切换、偏好持久化、旧配置默认值、选中保留、搜索、固定与复制。
- 已查看本次回归生成的真实窗口截图 `build/clipboard-layout-list-image.png`：图标、双行文字和无描边选中背景正常，无内容裁切；长标题尾部省略。

悬停颜色及拖放保留实现已检查，本轮未单独执行真实鼠标悬停或拖放验证。已有编译警告未纳入此次样式修改。

## 文档检查

README 中英文同步说明历史行与搜索结果共享样式。AGENTS.md 不变：未引入新命令、模块或系统访问边界。构建与回归产物沿用已有 `build/` 忽略规则，生成工程沿用 `Asky.xcodeproj/` 忽略规则。
