# 提醒卡片展开阴影遮挡

- 原因：原有阴影随每张卡片一起分层，仅剔除自身表面，上方卡片的阴影可绘制到下方玻璃及内容上
- 改为堆栈统一阴影底层，并以所有卡片轮廓共同排除阴影；轮廓同步卡片的高度、折叠缩放、位移和可见性，保留滑入结束后显示阴影的时序
- 增加仅 Debug 预览参数 `--test-banner-reflow`，配合 `--test-banner` 自动折叠后再次展开并暂停消失，供真实窗口复核
- 已执行 `xcodegen generate` 和 README 的 Debug `xcodebuild` 命令，最终结果 `BUILD SUCCEEDED`
- 已执行 `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，退出码 0
- 运行最终新构建 `Asky --test-banner --test-banner-reflow`，通过 Orca computer-use 捕获真实窗口：折叠时高度 243 pt，再次展开后高度 407 pt，出行提醒及操作按钮恢复显示；截图确认下方卡片顶部没有上方卡片阴影造成的暗带
- 自动化坐标点击因 nonactivatingPanel 的焦点检查受阻，未将点击验证记为通过；展开复核使用 Debug 入口调用相同的 `expand()` 路径
- 截图位于已忽略的 `build/reminder-shadow/folded.png`、`build/reminder-shadow/expanded.png`，复用现有 `build/` 忽略规则
- 未验证多屏与 macOS 15 的材质回退
- README: updated：中英文同步预览命令
- AGENTS.md: unchanged：未改变构建流程或模块边界，Debug 预览命令由 README 维护
