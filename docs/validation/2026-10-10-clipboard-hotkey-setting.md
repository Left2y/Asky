# 剪贴板快捷键可配置

- 默认组合键改为 ⌃⌥⌘V（Ctrl + Option + Command + V）：贴合“粘贴”语义，系统与常见应用均不占用。原 ⌃⌥⌘⇧F9 在多数笔记本上需额外按 fn，实际难以触发。
- 设置 › 触发快捷键新增“剪贴板”分区，可录制或恢复默认；存入 `SettingsPreferences`（`clipboardHotKeyCode/Modifiers/Label`），启动时按保存值注册。占用或注册失败时回退到上一个组合键并显示状态。
- `SettingsPreferences` 改为逐字段解码，旧版本保存的偏好缺少新字段时补默认值，不再整体丢弃。
- 录制标签改用不含修饰键的字符（`characters(byApplyingModifiers: [])`），避免 ⌥ 把 V 显示成 √；F1–F12、方向键等显示名称。

## 其他应用前台时无法唤起

- 面板是 `.nonactivatingPanel` 且平时为 `.normal` 层级，KulaHere 不会被激活，所以在其他应用前台时面板被压在其窗口下面，只有 Orca（截图里恰好无遮挡）看得到。现在显示时提升到 `.floating` 并 `orderFrontRegardless`，失去焦点且未固定时回落到 `.normal`。
- 实际验证：Finder、Safari、备忘录分别为前台时投递 ⌃⌥⌘V，CGWindowList 中“剪贴板历史”均在屏且层级为 3（floating），再次投递关闭。

## 悬停详情层

- 位置：面板下方 8 pt，水平对齐卡片中心；超出面板左/右边界时改为与卡片左/右边缘对齐；屏幕底部不够时翻到面板上方 8 pt。
- 图片按外层 24 pt 圆角、8 pt 内边距裁切为 16 pt 同心圆角，外层加 1 pt 边框。
- 文字按实际排版高度计算面板高度，上限 440 pt，超出部分在详情层内滚动；鼠标移入详情层保持显示。
- `python3 App/Tests/run-clipboard-regression.py`：新增居中、左对齐、右对齐、8 pt 间距与长文字高度上限断言，通过。

## 实际验证

- `xcodegen generate` 与 Debug `xcodebuild`：通过。
- `build/hotkey-regression`：通过。
- `python3 App/Tests/run-settings-regression.py`：浅深色快照通过，`build/settings-light-hotkey.png` 显示两个录制器。
- 退出旧进程、打开新 Debug 构建后，System Events 投递 ⌃⌥⌘V，KulaHere 出现“剪贴板历史”窗口；再次投递关闭。
- 设置内录制新组合键需人工测试。

## 选中、回车置入、图标与滚动

- 默认选中首张卡片，选中态为 2 pt `borderIntense` 描边（未选中 1 pt `border`）；←/→、↑/↓ 切换并自动滚动到可见区域。
- Return：写入剪贴板、关闭面板，80 ms 后向前台应用投递 ⌘V。面板为非激活面板，前台应用不变。需要辅助功能权限，缺失时系统提示一次，此时仅完成复制。
- 悬停弹层位置不对的原因：卡片锚点只在布局时记录屏幕坐标，横向滚动不触发重新布局，记录值停留在滚动前。现在在悬停时实时换算卡片的屏幕坐标。
- 来源图标：新增 `source_bundle_id` 列（schema v3），优先按 Bundle ID 解析，不依赖应用正在运行；旧记录按名称匹配时额外比较 `.app` 的本地化显示名（如“备忘录”→ Notes.app），结果缓存。
- 滚动：面板把以纵向为主的滚轮/触控板事件转换为横向事件，无需按住 Shift。
- `python3 App/Tests/run-clipboard-regression.py`：新增默认选中、左右切换边界、Notes 图标按 Bundle ID 解析、纵向转横向滚动断言，通过；`swift test` 145 项通过。
- 回车实际粘贴到其他应用、触控板惯性滚动需人工验收。

## 提交前复验（2026-10-10）

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：145 项测试通过。未指定 Xcode 工具链的首次运行因缺少 `Testing` 模块失败。
- `xcodegen generate` 与 README 中的 Debug `xcodebuild` 命令（指定上述 `DEVELOPER_DIR`）：通过。
- `python3 App/Tests/run-clipboard-regression.py`：退出码 0，通过。
- 此次未重新执行人工验收。
