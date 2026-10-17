# 视频播放控制条间距

- 目标：剪贴板视频预览中，原生浮动播放控制条的左、右、底部间距保持一致。
- 实现：保留 AVKit 控件，按实际水平间距约束底部位置；鼠标进入后重新布局，以覆盖 AVKit 延迟创建控件的情况。通过公开 AppKit 玻璃视图类型和尺寸排除视频分析按钮，不使用私有类名或 selector。
- 兼容范围：macOS 26 及以上的玻璃控制条；旧系统保留 AVKit 原有布局。若系统改变内部视图结构，无法识别时保留原生布局。

## 已执行检查

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- 独立原生播放器窗口：400 × 280 pt 时实测控制条左、右、底部均为 8 pt。

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --video-preview`：通过。列表与悬停预览均实测左、右、底部为 8 pt；播放推进、选中项切换释放资源、关闭预览及复制原文件均通过。
- 已查看 `build/clipboard-video-list.png` 与 `build/clipboard-video-hover.png`；列表截图可见三个方向的等距控制条，悬停截图处于控件淡出状态，间距以窗口视图实测结果为准。
- 构建与回归产物由已有 `build/` 忽略规则覆盖。保留任务开始前的快捷指令设置和本地化改动。

README 与 AGENTS.md 无需变更：本次仅调整现有控件间距，未改变使用方式、开发命令或架构边界。
