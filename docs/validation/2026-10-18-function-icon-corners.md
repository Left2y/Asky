# 功能图标圆角统一

- `LauncherFunctionIcon` 从 4.5 pt 连续圆角改为 4 pt 普通圆弧圆角，与 `CommandIcon` 的品牌图标一致。书签、链接、退出、换算以及复用此视图的 AI 图标共用此裁切；原始素材、符号大小与位置不变。
- `xcodegen generate` 与 README 中 Debug `xcodebuild` 命令通过。
- 使用临时原生预览程序展示实际 `LauncherFunctionIcon` 与 Google `CommandIcon`，已检查浅色、深色 NSWindow 中的渲染截图：`build/function-icon-corners-NSAppearanceNameAqua.png`、`build/function-icon-corners-NSAppearanceNameDarkAqua.png`。预览编译与运行通过；未替换已安装应用。
- KulaCore `swift test` 未全量通过：首次缺少 `AgentRuntime/dist/src/plugin-runner.js`，ToolServiceTests 的 `nativeWorkerRoundTripAndPolicy` 失败。尝试 `npm run build` 时发现缺少 pi-coding-agent、typebox 和 Node 类型依赖，TypeScript 构建失败；编译器仍生成了部分 dist 产物。再次运行 Swift 全量测试时 ToolServiceTests 已通过，但 AgentHostTests 的 `unreachableModelFailsAndProcessIsGone` 出现两项断言失败。未把全量测试记为通过。
- README: unchanged。此次仅统一图标裁切，不改变用法、构建命令或能力声明；具体参数已同步设计系统。
- AGENTS.md: unchanged。未改变模块边界、开发命令或持久规则。
