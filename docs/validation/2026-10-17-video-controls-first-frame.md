# 视频控制条首次出现时的位置

## 修复

此前鼠标进入后等待 0.1 秒再校正浮动控制条的位置，导致原生控件先按系统默认底部间距出现，再向下移动到 8 pt。

删除延迟任务与额外鼠标 tracking area。改为在主线程事件循环等待前校正 AVKit 异步创建的控制条，并同步完成原生子视图布局；校正不启用隐式动画。视图离开窗口时注销 run-loop observer。保留播放器接受父容器尺寸的修复。

## 已执行

- `xcodegen generate`：通过。
- README Debug `xcodebuild`：通过。
- `Packages/KulaCore` 的 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- 独立原生播放器：鼠标进入时以 10 ms 间隔采样，控制条首次观测位置即为 `(8, 8, 384, 100)`，后续采样没有位置变化。

- 竖版 `run-clipboard-regression.py --video-preview --portrait-video`：完整通过。
- 同一回归二进制使用横版 fixture：完整通过。列表和悬停控件出现期间，显示提交前采样的窗口、视频区域和控制条坐标保持稳定；最终三边均为 8 pt，播放、切换释放资源、关闭和原文件复制通过。

回归新增连续 400 ms 的显示提交前采样（在播放器布局校正之后执行），检查控件出现过程，分别约束窗口坐标、视频区域坐标与相邻显示帧的控制条坐标，避免只检查最终稳定位置。

README: unchanged——沿用已记录的横竖版视频回归命令。AGENTS.md: unchanged——没有改变持久开发规则。构建、视频和截图沿用已有 `build/` 忽略规则。
