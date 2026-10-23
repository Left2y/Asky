# 窗口跨屏操作验证

日期：2026-10-23。

## 行为

- `sw` 选中窗口后，`⌘K` 在多屏时提供“切换到上一块屏幕”和“切换到下一块屏幕”，默认 `⇧ ←` / `⇧ →`；“关闭窗口”仍在最下方。
- 单屏隐藏两项，快捷键不拦截；打开菜单及执行快捷键时重新检测屏幕数量。
- 按屏幕中心分布主轴排序，横向左到右、纵向上到下，首尾循环。窗口最大相交区域决定当前屏幕；跨屏保留相对位置并适配目标可用区域。
- 两个快捷键沿用启动器的配置、持久化、冲突检查与缺失值默认机制，中英文菜单和设置文案同步。
- 系统全屏窗口返回“请先退出全屏，再切换屏幕”。退出全屏动画未完成时，系统仍可能拒绝移动；本次真实移动检查在退出动画结束后执行。

## 已运行

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData-display-move build
ASKY_DERIVED_DATA="$PWD/build/DerivedData-display-move" DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --window-search
ASKY_DERIVED_DATA="$PWD/build/DerivedData-display-move" DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --window-search-live
```

- KulaCore 全套测试及 Debug 构建通过。
- 布局回归通过：左右顺序与循环、上下顺序与横向错位、单屏与无屏、跨屏及屏外窗口归属、相对位置与小屏适配。
- 原生菜单回归通过：两项顺序、快捷键默认值及冲突、单屏隐藏、关闭项负向样式、`⌘K`、键盘选择与 Esc。已查看浅色、深色窗口截图，文字和快捷键完整。
- 真实环境为内建屏幕和左侧 Mi Monitor。双向移动成功，独立窗口进程报告所在屏幕变化；全屏窗口移动被拒绝，原有全屏与精确窗口身份回归通过。默认 Shift Left 和自定义 Shift Command Right 经启动器实际分发并移动窗口，自定义后原按键不再触发。最后一次原生回归使用 `/tmp/asky-display-native-snapshot` 中的稳定 App 源码副本，避免并行插件工作在编译期间修改输入；该副本的屏幕切换代码与工作区一致。

## 验收边界

验证基于当前集成工作区，包含并行进行的插件与窗口身份校验改动；本次提交仅隔离屏幕切换相关改动。

上下排列由坐标测试覆盖，未调整用户显示器排列进行实机验证；单屏隐藏由菜单状态及布局回归覆盖，未拔除显示器。真实移动使用测试窗口和程序构造的键盘事件，不代表物理键盘输入、所有第三方应用、跨 Space 或热插拔均已验收。构建和截图沿用已存在的 `build/` 忽略规则。
