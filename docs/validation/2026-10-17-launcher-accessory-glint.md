# 启动器按钮开场白边

用户补充指出，固定和筛选按钮在开场动画期间边缘变白，暗色下尤其明显。代码检查发现 `LauncherAccessory` 在原生玻璃上额外叠加了 1pt 白色 `Circle.strokeBorder`，以 `keyframeAnimator` 做峰值 32% 透明度的闪光，且两个按钮错开 35ms。此前仅根据共用玻璃配置推测背景反光，漏查了这层显式描边，应以本记录修正该解释。

本次移除白色圆环及其关键帧，保留既有窗口分离弹簧、位置、透明度、原生玻璃、系统阴影、悬停和按压效果。共享显示状态继续用于按钮的辅助功能可见性。

## 实际验证

- `xcodegen generate`：通过，日志 `build/launcher-glint-generate.log`。
- README 中 Debug `xcodebuild` 命令：通过，日志 `build/launcher-glint-build.log`。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：已执行，仍有 `RealRuntimeIntegrationTests.unreachableModelFailsAndProcessIsGone` 两处断言失败（没有 running 状态和 runningPID），与上一轮相同；未修改相关代码，未认定根因。日志 `build/launcher-glint-swift-test.log`。
- `git diff --check`：通过。代码差异确认移除了整层白色描边，不改动窗口动画和交互；此次未新增测试、未重跑原生窗口回归或逐帧视觉验收。

未替换已安装的应用，未打包或发布。README / AGENTS.md 保持不变：没有新增开发命令、使用步骤或架构边界。产物沿用现有 `build/` 忽略规则。
