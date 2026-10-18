# 剪贴板顶部搜索区统一

卡片与列表共用顶部输入行：复用主搜索的 52 pt 高度、左 28 / 右 22 pt 留白、12 pt 间距和 26 pt 输入控件；底部 1 pt 分割线两侧各内缩 28 pt。移除左侧搜索图标及独立胶囊玻璃，筛选与窗口固定按钮保留在同一输入区右侧。

## 实际验证

- `xcodegen generate` 与 README Debug `xcodebuild` 命令通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 通过。
- 原生 `--filters` 回归通过：类型筛选、搜索交集、重置与菜单生命周期。
- 隔离快照的 `--layouts` 回归通过：布局切换、选择、搜索、固定、复制与设置保存。
- 通过 `orca computer` 查看新编译的真实列表和卡片窗口，确认输入行无搜索图标、无独立胶囊背景，分割线两侧留白，筛选与 Pin 位于右侧。列表输入 `Another` 后只显示匹配项；点击筛选按钮打开菜单，选择“全部”返回主窗口。
- 截图保存在本地忽略的 `build/clipboard-header-list-native.png` 与 `build/clipboard-header-cards-native.png`。

## 回归前提与并行改动

工作区原有粘贴兼容性代码与回归修改均保留。首次布局回归编译被并行测试文件修改中断；改用 `build/ClipboardHeaderRegression.swift` 快照隔离。现有布局回归仍断言旧默认卡片，与仓库当前默认列表不符；仅在临时快照中将旧配置默认断言修正为列表，并显式从卡片开始验证视图切换，没有修改项目测试文件。

## 纯图标按钮与列表竖线修正

根据截图反馈，顶部 Filter / Pin 去掉 `LauncherActionButtonStyle` 的常驻玻璃底板，恢复历史提交 `44f4ac8` 中搜索图标按钮的反馈方式：普通状态只显示图标，悬停显示 60% 语义反馈，按下显示完整反馈，支持减少动态效果。卡片与列表使用同一控件。列表竖线顶部内缩 12 pt，底部避开操作栏并再内缩 12 pt。

- 再次执行 XcodeGen、README Debug 构建与 KulaCore `swift test`，均通过。
- 新构建的 Debug App 卡片窗口实际检查通过：Filter 与 Pin 的圆形玻璃底板已消失。
- 新编译的列表预览通过 WindowServer 截图检查：两个按钮普通状态仅显示图标，中间竖线顶部与横线分离，底部止于操作栏上方；截图位于本地忽略的 `build/clipboard-header-pure-icons-list.png`。
- 修正后重新运行原生 `--filters` 回归通过：类型、搜索交集、重置和菜单生命周期。

## 右侧图标与搜索区尺寸对齐

主搜索图标原占 19 × 24 pt 布局槽，而剪贴板图标按钮占 32 × 32 pt，同样右留白 22 pt 时图标中心相差 6.5 pt。现在主搜索和剪贴板复用 `LauncherLayout.inputAccessoryWidth/Height` 的 19 × 24 pt 布局槽，图标均为 17 pt，右侧最后一个图标中心距窗口右缘 31.5 pt。剪贴板按钮内部仍为 32 × 32 pt 点击范围，外部槽只影响排版，不裁剪按钮。两个输入区共用 `LauncherLayout.inputHeight = 52`，剪贴板外圆角沿用主搜索的 26 pt。

- XcodeGen、README Debug 构建与 KulaCore `swift test` 实际运行通过。
- 新构建 Debug App 列表窗口经 `orca computer` 截图核对：2× 截图中右侧 Pin 中心约 x=1218，窗口宽 1280 px，对应距右缘约 31 pt；输入区底部分割线位于 y=104 px，对应 52 pt。
- 截图保存在已忽略的 `build/clipboard-header-alignment-native.png`。
