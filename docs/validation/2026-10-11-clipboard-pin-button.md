# 剪贴板窗口 Pin 按钮修复

## 定位与改动

前一版误改了 AI 窗口标题栏；用户截图对应剪贴板窗口右上角的 Pin。剪贴板原实现将圆形背景放在 Button 外，且没有悬停状态。

本次将背景和 32×32 圆形 contentShape 一起放入 Button label，并以独立 View 的 onHover 状态绘制主题 InteractionHover。置顶与取消置顶同步更新辅助功能标签、值和提示。保留原有图标、尺寸和窗口置顶逻辑。

## 初次验证（构建曾被许可协议阻塞）

- Xcode 工具链 `swiftc -frontend -parse App/Sources/ClipboardWindow.swift`：通过，仅语法解析。
- `git diff --check`：通过。
- `xcodegen generate`：通过。
- 核心 `swift test` 和 README 中的 Debug `xcodebuild`：均退出 69，Xcode 许可协议仍未接受。
- 没有启动修改后的窗口；整圈空白区域点击、悬停视觉和置顶切换仍待实际验收，不能记为通过。

README: unchanged — 小范围交互修复不改变使用方法或开发命令。
AGENTS.md: unchanged — 不改变持久工程约定或模块边界。

## 许可处理后的实际验证

- 用户明确授权代为处理后，经 macOS 原生管理员认证执行 Xcode `-license accept`，退出 0。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，退出 0。
- `xcodegen generate` 与 README Debug `xcodebuild`：通过，日志含 `BUILD SUCCEEDED`。
- 关闭旧 KulaHere 进程，启动 `build/DerivedData/Build/Products/Debug/KulaHere.app`；本次构建的可执行文件时间为 09:44:15，旧文件为 00:09:32。
- 原生验证使用 `run-clipboard-regression.py --preview` 编译真实 App 源码，临时测试库不涉及用户真实剪贴板内容。
- 脚本首次失败：SDK 26.5 与构建产品 SDK 27.0 不一致。指定 `SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk` 后重试。
- 第二次失败：其他并行工作修改了 `AgentModel.swift`，编译器报告 input file was modified during the build。重试后成功编译并显示原生剪贴板窗口。
- CUA 实际点击读取状态：中心点击由“固定窗口 / pin”变为“取消固定窗口 / pin.fill”；圆形左侧空白 `(1718, 60)` 及上侧空白 `(1744, 34)` 均成功取消固定（坐标为 1800×488 截图像素）。
- 截图对比：鼠标移出按钮后恢复普通背景，进入圆形区域后显示悬停反馈。截图含系统指针强调光晕，该光晕不是按钮背景。
- 自动化坐标点击未固定面板时可能因失焦隐藏导致工具超时；先固定面板后完成上述空白点击验证。未将工具超时记作通过。
- 验证结束关闭临时 ClipboardRegression 进程，保留主 KulaHere 程序运行。未运行完整剪贴板回归套件，此处只确认指定交互。
