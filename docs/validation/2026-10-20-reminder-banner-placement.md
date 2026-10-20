# 提醒卡片右上角定位

## 修改

- 不再缓存屏幕右边缘和顶部坐标。每次展示、窗口增高或缩短时，通过显示器 ID 从当前 `NSScreen.screens` 读取最新 `visibleFrame`。
- 同一组可见提醒保持在原显示器；原显示器不存在时回退到鼠标所在屏幕。新一组提醒重新选择鼠标所在屏幕。
- 收到 `NSApplication.didChangeScreenParametersNotification` 后立即重新定位可见提醒。
- 新提醒到来时取消旧的延迟缩窗任务，避免旧任务覆盖新尺寸。
- 自绘 panel 保留计算出的窗口位置，避免 AppKit 因顶部透明阴影留白超出 `visibleFrame` 而整体下移。原生回归在添加此修正前实际测得向下偏移 12 pt，修正后坐标精确匹配。

## 已执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：`BUILD SUCCEEDED`。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：退出码 0。
- 临时原生回归从修改后的源码提取 `ReminderBannerCenter`、堆叠模型与真实 `ReminderBannerPanel`，仅将卡片视图替换为空视图，手动报告高度；使用真实 AppKit 窗口逐项断言窗口 frame：首次显示、窗口移至中间后发送屏幕变化通知、新提醒重新校准、堆叠增高、隐藏后重新显示、主屏、副屏负坐标、无效显示器 ID 回退，均通过。
- 新构建的真实 App 以 `--test-banner` 启动，未启动用户数据或调度器。通过 Orca 捕获卡片截图并检查，卡片正常显示；窗口坐标 `x=1074, y=21, width=408, height=243`（Orca 顶部原点坐标），卡片含 24 pt 透明阴影留白，位于屏幕右上角。预览进程已退出。

本地证据保存在已忽略的 `build/banner-placement-validation/`，含原生回归生成器、提取源码、回归日志、构建与测试日志，以及 [实际卡片截图](../../build/banner-placement-validation/preview.png)。

## 验证边界

未实际拔插显示器或调整系统缩放；屏幕变化通知由回归进程内发送，显示器消失通过无效 ID 模拟。用户截图对应的具体触发条件尚未复现，本次覆盖已发现的定位失效路径。

README 与 AGENTS.md 保持不变：修正已有右上角定位行为，不改变使用方式、开发命令或模块边界。
