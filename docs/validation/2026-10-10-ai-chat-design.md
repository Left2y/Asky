# AI 对话 Figma 样式验证

日期：2026-10-10。

## 设计依据与实现

用户指定 [UI 页 22:293](https://www.figma.com/design/tmVnTyCb2sz5egNQ7We9Sw/Asky?node-id=22-293)。通过页面结构确认 AI 对话 frame 38:554（窗口 38:555）与历史 frame 38:653（窗口 38:654），分别读取高保真设计上下文与截图。

- 对话窗口初始 720 × 640 pt、最小 640 × 560 pt，普通层级透明可调整大小的 NSWindow，支持键盘焦点与拖动。
- 32 pt 外壳圆角、70% 语义底色、原生 Regular Liquid Glass、1 pt border；采用系统窗口阴影。背景壁纸仅为 Figma 展示上下文，不进入 App。
- 顶部 56 pt：历史按钮、居中标题、关闭按钮；历史页在同一外壳中替换正文，支持按标题过滤、选择、新对话和删除。
- 用户气泡 16 pt 圆角，正文与工具行 16/400/Default，正文左右 32 pt；工具与正文 12 pt 间距。
- 工具行以 calendar、checklist、note.text、person.crop.circle、message、globe、square.stack.3d.up、brain 对应实际工具，未知工具回退 gearshape。状态文字与权限设置入口保留。
- 底部 24 pt 圆角输入区，保留附件、导入、拖入、截屏、剪贴板、发送与停止；附件菜单提供新对话和设置。输入自动聚焦。

## 实际执行的检查

1. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，工作目录 `Packages/KulaCore`：117 tests / 23 suites 通过，包括真实 Runtime 集成测试（未调用真实模型服务）。
2. `xcodegen generate`：成功。
3. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：最终源码构建成功。Xcode 输出已有 iOS Simulator 版本警告，macOS 构建未受阻。
4. 临时独立 AppKit 预览编译真实 AgentView / WindowPresentation，使用内存中的示例模型，不写入数据库、不读取 Key、不调用模型或系统工具。用 Orca computer-use 读取窗口树、点击历史按钮，确认历史页出现；正文输入值与发送按钮启用状态已回读。
5. 使用实际桌面区域截图检查浅色、深色玻璃。单窗口 ScreenCaptureKit 截图会缺失背后颜色，因此增加独立进程的彩色背景窗口，桌面合成截图确认材质透出底层颜色且文字清晰。预览还覆盖历史过滤（初始查询“日程”只显示匹配会话）和减少透明度分支（仅临时预览强制该值，不修改系统设置）。
6. 原生窗口测量为 720 × 640 pt。截图为 Retina 2×：1440 × 1280 px。最终浅色截图已在移除正文额外 60 pt 右侧空白后重拍。
7. `git diff --check`：通过。README 中英文同步了界面与设置入口说明；AGENTS.md 无需变更，模块边界与开发命令未改变。

临时预览及截图位于忽略的 `build/ai-design-preview/`：`light-final.png`、`dark-history.png`、`reduce-transparency.png`。预览进程在检查后退出。

## 验证边界

本次未替换或安装运行中的 KulaHere，未进行真实模型回复、实际工具执行、钥匙串授权、文件导入或删除真实会话的回归。完整 VoiceOver、键盘快捷键、多显示器、调整窗口大小与最小化恢复仍需实际 App 验收。深色和减少透明度预览在最后一次正文宽度微调之前拍摄；该微调未涉及材质。系统玻璃与阴影是原生映射，不宣称与 Figma 光学参数逐项一致。构建完成后需重新打开新构建才能看到改动。
