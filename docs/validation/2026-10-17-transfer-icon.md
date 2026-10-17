# 换算图标替换

将共享 `arrow.left.arrow.right` 映射从 `transfer_horizontal` 改为 MingCute regular `transfer`，即 `transfer_line` 对应的上下两条反向箭头。使用清单固定版本 `ca98bb55513a22ff0dab713aaf7870b512944653` 的原始 SVG，保留原尺寸、模板颜色与布局；同步资源清单并移除旧资源。

## 实际检查

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `cd MCPBridge && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`：通过。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：未全部通过；`PluginTests.nativeWorkerRoundTripAndPolicy` 因缺少 `AgentRuntime/dist/src/plugin-runner.js` 失败。补构建 MCPBridge 后复查结果相同。
- `cd AgentRuntime && npm run build`：失败，当前依赖环境缺少 TypeScript 所需模块/类型，未改动依赖配置。
- TypeScript 在报错时仍产出部分 `dist`，再次执行核心测试：插件测试通过，但 `AgentHostTests.unreachableModelFailsAndProcessIsGone` 因运行时依赖不完整失败；最终完整套件仍未通过。
- `git diff --check`：通过。
- 已启动新构建应用并访问剪贴板窗口；未完成换算窗口视觉验收，不能据此声称视觉检查通过。

README 与 AGENTS.md 无需随此图标替换修改：使用方式、构建命令与架构边界均未变化。保留原有其他图标、文档与清单修改。

Git：并行的书签、链接修改已独立提交，本次仅提交换算图标、映射与验证记录；保留剪贴板相关未提交修改。生成物继续由既有 `build/` 与 `AgentRuntime/dist/` 规则忽略。
