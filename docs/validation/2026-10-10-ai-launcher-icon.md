# AI 搜索图标

- 使用用户提供的 `Agent.png`，存入 `App/Assets.xcassets/Agent.imageset`。
- AI 结果使用原有 32 pt 图标容器；内部 3 pt 留白，白底图像使用 6 pt 连续圆角，与链接和书签 logo 的占位方式对齐。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 `Packages/KulaCore`）：130 tests / 27 suites 通过。
- 初次未设置 `DEVELOPER_DIR` 的测试因 Command Line Tools 缺少 `Testing` 模块失败，切换完整 Xcode 工具链后通过。
- Debug App 已运行；自动化获取的窗口截图与启动器 accessibility 树不一致，未取得 AI 结果行的可靠截图，因此实际像素验收仍未确认。未提交 AI 请求。
- README 中英文补充图标说明；既有构建流程与系统边界不变，AGENTS.md 无需更新。

## 阴影补齐

- 用户截图显示 AI 白底图标缺少 App logo 的投影；在圆角裁切之后、留白之前添加黑色 16% 不透明度、1 pt 模糊半径、向下 1 pt 的阴影。
- 再次执行 `xcodegen generate`、上述 Debug 构建和完整 Xcode 工具链的 `swift test`：均通过，130 tests / 27 suites。
- 已退出旧进程并启动新 Debug 产品。GUI 自动化仍停留在 AI 对话窗口，未取得启动器图标截图；不将实际界面阴影验收记为通过。
