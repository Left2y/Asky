# 启动器 Pin / Filter 与玻璃展开验证

## 实现

- 总宽度固定 720 pt、高 64 pt。空输入时搜索框占 568 pt；Pin、Filter 为 64 × 64 pt 圆形按钮，间隔 12 pt。输入后按钮隐藏并禁用点击与辅助功能曝光，搜索框恢复 720 pt；清空后恢复按钮。默认不固定、搜索全部。
- 搜索框与按钮各自使用原生 Regular 玻璃。搜索框快速缩短，按钮从右向左滑入，由 82% 缩放轻弹到完整大小；按钮弹簧响应 280 ms、阻尼 0.78，Pin 比 Filter 晚 35 ms，并有一次短暂边缘亮光。空输入的缩短及清空结果收起使用 120 ms，开始搜索的合并使用 180 ms；降低动态效果时直接呈现。最终动画验证见[跟随动画记录](2026-10-11-launcher-accessory-follow-motion.md)。
- Pin、Filter 的 SF Symbol 字体大小均为 17 pt，与搜索放大镜一致；按钮仍为 64 × 64 pt。
- Pin 阻止失焦隐藏；Escape 可以关闭固定窗口，优先关闭筛选菜单。关闭窗口重置本次固定与筛选状态。
- Filter 的玻璃菜单可选择全部、应用、文件、快捷方式（内置网页指令和别名）、系统快捷指令。选定类别会限制搜索 provider 与直接结果；不会以计算卡片或 AI 结果替代限定搜索。
- 玻璃效果直接作用于控件内容，避免融合容器中的背景材质遮挡文字和图标。使用原生 Regular 材质；透明度与对比度辅助功能使用不透明回退。

## 实际运行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（KulaCore）：通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/run-launcher-window-regression.py --accessories`：Aqua / Dark Aqua 通过。
- 最终玻璃合成修正后，冻结当时的 App Swift 源码与 Debug 模块，用同一原生回归入口重新编译并运行 `--accessories` 与默认完整回归：Aqua / Dark Aqua 均通过。冻结副本用于避免同一工作区另一项玻璃样式任务在编译时修改源码与对象文件，未修改生产数据。
- `--accessories` 验证类别隔离、限定搜索不消费关键词/不回退到 AI、固定/取消固定失焦行为、Escape 优先级、菜单画布和输入位置。
- 默认回归最初的系统滚轮检查失败；原生测试进程在发出系统输入前显式激活后重跑通过。验证了行式/精确滚轮在结果区、输入区和边缘的投递，背景滚动位置保持不变；键盘导航及列表滚动通过。连续输入与结果变化时输入框垂直漂移为 0.0 pt。
- 原生浮窗截图检查与菜单操作：文字、搜索图标、Pin 和 Filter 可见，菜单五个类别可展开并选择；没有使用 SwiftUI 离屏渲染作为视觉证据。
- 两份 `Launcher.strings` 的 `plutil -lint`：通过。README 的中文与英文使用说明及回归命令已同步。

## 限制与工作区

- 原生屏幕录制的中间帧检查已确认玻璃先鼓出球状，再形成两处收窄连接，最终分离为两个圆形按钮；录制同时覆盖输入后的合并与清空后的展开。展开片段保存为本地 build/launcher-accessories-morph.mp4，沿用 build/ 的忽略规则。未改变系统辅助功能设置进行物理验收。
- 本次未打包、安装或发布。工作区存在另一任务对同一个 LauncherView 和共享玻璃材质的并行修改，未将这些混合变更作为本次独立提交。

## 宽度与合并速度修订

- 修订后的 Debug 构建通过；KulaCore 测试通过。
- 宽度分配回归要求空输入与搜索时窗口宽度均为 984 pt（720 pt 可见界面加 264 pt 透明画布）。检查默认未固定、全部来源，以及输入/清空时原生 NSTextField 宽度增减 152 pt。
- 修订后的默认完整原生回归在 Aqua / Dark Aqua 通过：系统滚轮、背景滚动隔离、键盘导航和稳定输入位置仍正常，输入漂移为 0.0 pt。
- 用户认可展开动画后，仅将开始搜索的合并缩短为 180 ms；展开参数保持不变。针对性回归进一步检查输入 300 ms 后已经回收按钮空间。

## 固定位置的液体断开与图标尺寸

- 移除玻璃元素之间的位置匹配转场，使用可动画轮廓在两个固定间隔处收细连接；断开后分离的轮廓横向回缩为圆形。图标位置固定，仅淡入。
- 新构建通过，KulaCore 测试通过；`--accessories` 原生回归 Aqua / Dark Aqua 通过，输入 300 ms 后回收按钮空间的检查通过。
- 重新录制真实原生窗口，检查了连续轮廓、两处收细的连接与最终分开的圆形中间帧；本地动画预览已更新。
- 液体轮廓修订后的默认完整原生回归也在 Aqua / Dark Aqua 通过：行式/精确滚轮、输入区/边缘投递、背景滚动隔离、键盘导航及稳定输入位置通过。

## 快速缩短、轻弹与清空速度

- 根据后续澄清，最终动画为搜索框缩短与圆形按钮轻弹；移除自定义液体轮廓。总宽度 720 pt、图标 17 pt、按钮 64 pt、默认未固定及全部来源保持。
- 将结果列表的清空收起与按钮弹簧分开。`--accessories` 在清空后 220 ms 检查窗口已回到 328 pt（含透明画布）、输入框已恢复空输入宽度：Aqua / Dark Aqua 均通过。
- 保持按钮标签内的 64 pt interaction contentShape；与工作区已有按钮悬停、按下样式共同生效。
- 最终 Debug 构建通过；KulaCore 测试通过。另一任务修改了剪贴板拖拽接口并移除了一段不稳定的合成点击测试，冻结最新源码、最新回归入口及 Debug 模块后运行本次原生检查，避免编译过程中输入文件改变。
- 实际屏幕录制检查快速缩短与轻弹出现；本地预览为 build/launcher-accessories-animation.mp4，沿用 build/ 忽略规则。
- 快速缩短/轻弹版本的完整原生回归在 Aqua / Dark Aqua 均通过，滚轮、背景滚动隔离、键盘导航和输入位置检查通过；输入垂直漂移为 0.0 pt。
