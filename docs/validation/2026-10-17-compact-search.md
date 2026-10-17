# 搜索紧凑布局验证

按用户提供的 Tinycast 截图调整搜索密度：输入高 64 → 52 pt，结果行高 50 → 38 pt，图标 32 → 24 pt，分组标题 52 → 30 pt。结果改为单行名称，移除路径与副标题，右侧显示应用、文件格式或来源类型。路径复制及访达定位保留。

用户复核指出空输入圆角变形后，修正原生玻璃及多层裁剪保留 32 pt 半径的问题：收起统一为 26 pt 圆弧。用户随后要求展开结果也保持一致，最终收起与展开均为 26 pt 圆弧。

## 已执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：261 个 Swift Testing 测试通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --compact-results`：浅深色通过。真实原生窗口渲染应用、PDF、带扩展名的目录和长中英文文件名；PDF/目录格式断言通过。已查看 `build/launcher-compact-NSAppearanceNameAqua.png` 与 `build/launcher-compact-NSAppearanceNameDarkAqua.png`，名称省略时类型仍可见。图片来自原生视图缓存，不能用于判断桌面玻璃与阴影效果。
- 运行同次编译的 `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression --bottom-clearance`：浅深色通过；滚轮/精确滚动、正反方向、输入区与结果区、键盘首尾导航、最后一项底部留白均通过。

- 同次编译的原生回归 `--accessories`、`--ai-routing`：浅深色通过，覆盖按钮表面、重复展开收起、筛选和 AI 回退路由。

- 圆角修正后重新执行 `--compact-results`：浅深色通过；收起与展开窗口均通过 26 pt 半径和圆弧曲线断言；已重新查看最终展开结果的深色截图，外框转角与收起状态一致。已查看系统窗口截图 `build/launcher-compact-empty-NSAppearanceNameAqua.png` 与 `build/launcher-compact-empty-NSAppearanceNameDarkAqua.png`，两端为半圆，与相邻圆形按钮高度一致。

## 限制

默认完整窗口回归运行两次，均在系统 CGEvent 投递阶段失败：边缘位置事件前面板失去 key 状态（首次还收起为 52 pt 空输入窗口），随后断言 `system wheel must reach launcher` 未通过。前面的行内与输入区域事件能滚动前景且背景位置不变；专项直接投递滚动测试通过。未据此认定系统事件全链路通过，也未确认失败是否由此次样式变化引入。

截图与测试产物沿用 `build/` 忽略规则；未替换 `/Applications` 中的安装版本。
