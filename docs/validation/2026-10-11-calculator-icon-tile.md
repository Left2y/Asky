# 计算器图标与 AI 使用相同圆角方块

日期：2026-10-11

用户指出此前的透明竖长计算器与 AI 圆角方块不一致，本次修正该形态。

- 直接使用用户原图 `Calender.png`，保存为 `App/Assets.xcassets/Calculator.imageset/Calculator.png`；SHA-256 与原图一致，未重新生成或修改图像。移除此前透明生成图的 2x 文件，资源声明与 AI 同为 universal 图片。
- `.calculator` 和 `.askAI` 共用一个 SwiftUI 分支，仅选择的图片资源不同：32 pt 外框、3 pt 内边距、26 pt 图片、6 pt 连续圆角、黑色 0.16 阴影（radius 1，x 0，y 1）。保留原图白色底板，形成与 AI 一样的圆角方块。

已执行验证：

- 核心 `swift test`：全部套件通过。
- `xcodegen generate`：成功。
- Asky Debug `xcodebuild`：BUILD SUCCEEDED。
- 两份原图 SHA-256：`00cfcb5bc89fe4fc69c03b6173c789054df51d972d86a161737248159cb4e774`，一致。

原生预览使用临时独立进程、真实 LauncherPanel / LauncherView 和本次 Debug Assets.car，通过直接设置查询避开本机模拟键入的 IMK 输入法干扰。预览资源与产物继续由已有 `build/` 规则忽略，没有安装或打包 Release。

带本次资源的原生预览在 Aqua、DarkAqua 均通过；已人工查看新生成的两张计算器窗口截图，确认计算器与相邻 AI 图标均为同尺寸白色圆角方块，边距和阴影一致。

README: unchanged；仅修正图标形态，功能与使用方式不变。AGENTS.md: unchanged；没有新增开发规范或模块边界。提交仅包含此次图片、资源声明、删除旧 2x 文件、共用渲染分支及本验证记录，保留其他工作区修改。
