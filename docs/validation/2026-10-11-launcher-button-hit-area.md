# 启动器圆形按钮交互修复

- Pin / Filter 共用 LauncherAccessoryButtonStyle。64 pt 圆形玻璃材质位于 ButtonStyle 的标签内，整圆使用 interaction contentShape；背景不再位于 Button 外层。
- 悬停使用 InteractionHover 的 60% 高亮；按下使用完整高亮及 0.96 缩放。关闭动态效果时不播放动画，禁用状态不高亮。原尺寸、间距与图标保持不变。
- 原生鼠标验证在图标外侧的圆面点击，检查按钮状态。

## 实际检查

- xcodegen generate：通过。
- README 的 Debug xcodebuild 命令：通过。
- --accessories：冻结当前 App 源码与 Debug 模块，在 build/button-verification 内编译，Aqua / Dark Aqua 均通过，覆盖既有筛选、宽度、固定、Escape 检查。
- 实际原生窗口：Orca ScreenCaptureKit 截图检查默认、悬停和按住状态。圆面悬停高亮、按下缩小可见；通过系统鼠标事件点击固定按钮中心右侧 22 pt，辅助功能状态从 Off 变为 On。最后还通过 Orca 分别点击 Filter 和 Pin 中心左侧 22 pt，Filter 菜单展开且状态为 On，Pin 状态为 On，确认两颗圆面均响应。
- KulaCore swift test：最初因工作区既有 ClipboardAccessTests 引用缺失的 ClipboardAccess.dragProvider 失败；另一任务修复后重跑通过。最终 Debug 构建也通过。
- 临时八点合成鼠标回归首次通过，但重复运行有漏点；系统投递与本地事件队列均不够稳定，未保留此回归。实际窗口圆面点击由状态读回单独确认。
- git diff --check：通过。build/button-verification 沿用已有 build/ 忽略规则。

## 文档与提交

- README: unchanged，修复现有按钮交互，不改变使用方式或开发命令。
- AGENTS.md: unchanged，未改变架构边界或持久开发规则。
- 未提交：LauncherView、原生回归文件已有并行未提交改动；本修复依赖尚未提交的按钮和 NativeGlassBackground 实现，无法形成完整独立提交。
