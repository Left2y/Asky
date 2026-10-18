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
