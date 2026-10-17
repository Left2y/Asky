# 视频预览尺寸稳定性

## 问题与修复

用户反馈视频起初正常，播放控制条出现后突然变成矮横条。AVPlayerView 的 intrinsic size 会随浮动控制条改变；NSViewRepresentable 未声明尺寸响应时，SwiftUI 会采用新的原生高度，导致画面区域收缩。

播放器现在显式接受父容器提出的有限宽高，不再随控件的 intrinsic size 改变。控制条延迟创建后再校正底部间距，保留三边等距和原生播放交互。此次没有改变画幅缩放策略或悬停窗口的尺寸规则。

## 验证

- `xcodegen generate`：通过。
- README Debug `xcodebuild` 命令：通过。
- `Packages/KulaCore` 中 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- 独立原生竖版播放器窗口：鼠标移入后控制条左、右、底部均为 8 pt。

- `run-clipboard-regression.py --video-preview --portrait-video` 生成并编译竖版回归；首次运行在悬停窗查找处因真实鼠标跟踪时序失败，使用同一二进制和 fixture 重跑完整通过。
- 同一回归二进制分别运行 360 × 640 竖版和 640 × 360 横版：列表视频在控件出现并等待两秒后保持 399 × 282 pt，悬停视频保持 448 × 252 pt；两个场景三边间距均为 8 pt。播放推进、切换释放资源、关闭和原文件复制通过。
- 查看实际窗口截图：`build/clipboard-video-portrait-list.png`、`build/clipboard-video-portrait-hover.png`、`build/clipboard-video-list.png`，画面区域保持完整高度，没有变成矮横条。

README 中英文同步新增 `--portrait-video` 回归参数。AGENTS.md 无需更新：没有新增架构边界、独立模块或必需开发流程。所有构建、截图与视频产物沿用已有 `build/` 忽略规则。
