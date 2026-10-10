# 搜索输入与指令状态

日期：2026-10-10。

## 设计来源与实现

- 用户提供的 UI 页面 `22:293`：读取 metadata 后分别读取 `22:364`（普通结果）与 `43:1475`（快捷指令）的完整 design context 和截图，并单独请求搜索壳 `22:365`、`43:1476` 的截图。
- 普通输入：720 pt 宽、64 pt 输入区、28 pt 两侧边距、18 pt 字体、右侧放大镜、32 pt 外壳圆角；空输入保持之前的 720 × 60 pt 胶囊。
- 列表：12 pt 内边距、52 pt 分类标题、64 pt 结果行、40 pt 图标、12 pt 图文间距、16 pt 行内边距与 24 pt 圆角。最大高度改为 640 pt，容纳设计中约 628 pt 的普通结果面板。
- 已配置关键词加空格进入指令模式；左侧 24 pt 默认浏览器图标，输入框隐藏关键词前缀，结果显示指令名称与关键词标签。不加载普通搜索 Provider；Return 执行，⌘Return 仍可显式交给 AI。Escape 退出指令模式，正文为空时 Backspace 也可退出。
- 内置 `go` 与设置中创建的 `saf` 等自定义关键词共用状态样式。不新增应用别名数据模型或改变 macOS Shortcuts 的执行协议。
- 普通结果包含已配置的默认搜索命令和显式 AI 动作。剪贴板 Provider 从普通搜索移除；记录设置不变。独立剪贴板快捷键和面板等待用户下一份设计，不在本次实现范围。
- Wallpaper 是桌面参考，Safari 图标是动态应用数据示例；真实应用、文件及默认浏览器图标经 KulaCore ToolService 的展示接口取得。SF Symbols 按设计名称使用；分隔线采用原生 SwiftUI 绘制。产品源码没有临时 Figma 资源 URL，也没有将整张设计截图当作界面素材。
- 背景、文字、边框、悬停与选中沿用现有语义颜色和原生玻璃；减少透明度继续使用不透明背景。

## 已实际运行

1. `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：120 tests / 24 suites 通过。新增覆盖完整关键词、空查询、大小写、自定义 saf、输入尾随空格保留；现有路由及 Runtime 测试也通过。
2. `xcodegen generate`：成功。
3. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：最终 `BUILD SUCCEEDED`。
4. `git diff --check`：通过。

## 未完成的现场验收

尝试启动 Debug App，通过 Orca computer-use 观察和唤起搜索；工具无法通过 bundle ID 枚举 accessory App，PID 方式返回 `window_not_found`，Finder 的辅助功能读取返回 `permission_denied`。备用原生电脑工具能读取 AI 窗口，但快捷键没有可靠切换到搜索浮窗；临时 Debug 预览入口也未获得可验证的搜索截图，已撤去。

因此，没有把搜索浮窗的截图对比、实际透明桌面合成、深色模式、减少透明度、键盘导航、Escape/Backspace、点击与真实指令执行记为通过。需在最终构建上手动验收。未为检查执行网络搜索、提交 AI 消息或运行系统快捷指令。未打包 Release 或安装到 Applications。

README 已同步两种输入状态、配置条件及剪贴板范围；AGENTS.md 无新的稳定规则需要更新。
