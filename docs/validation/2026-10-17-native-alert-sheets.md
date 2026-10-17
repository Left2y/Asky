# 原生 Alert Sheet

日期：2026-10-17。macOS 27.0.1，本地 Debug 构建。

## 修改

此前独立 `NSAlert.runModal()` 的应用图标区与布局不符合参考图。应用内有所属窗口的 alert 改由 `AppDialog.present` 调用 AppKit `beginSheetModal`，并移除强制应用图标。没有所属窗口的启动错误和安装提示保留独立系统 alert。没有自绘弹窗表面，也没有修改响应按钮的 frame、圆角、字体、间距或布局。

用户明确选择系统自动布局：两个简短按钮横排、三个按钮纵排。DEBUG `--test-confirmations` 增加有真实窗口的 sheet 预览，首项使用参考图的标题、正文与三按钮；其余保留四项工具确认与三项应用提示，均不执行真实操作。

弹窗以异步回调返回结果，工具确认保留串行队列；拒绝全部时通过 `endSheet` 关闭所属 sheet。日程表单改为异步等待原生弹窗，确认之前不写入。

## 实际验证

- `xcodegen generate`：通过。
- README 的 Debug `xcodebuild`：通过，`BUILD SUCCEEDED`。
- `(cd MCPBridge && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build)`：通过。
- `(cd AgentRuntime && npm ci && npm run build)`：通过，仅恢复本地依赖及构建产物，未修改 runtime 源码。
- `(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)`：最终全量通过。初次运行因缺少 `AgentRuntime/dist/src/plugin-runner.js` 失败，补齐前置构建后重跑通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-message-calendar-regression.py`：通过，实际表单模型校验与取消不写入。
- 实际 Debug App 预览（最终 PID 88482）：八项弹窗逐项读取并点击 Cancel / 不执行 / 好，全部完成并退出预览；三按钮原生 sheet 无图标、按钮纵排，双按钮保持系统横排。此前同实现 PID 83571 已读回详情展开后的参数内容、确认执行后下一项标题，以及后续拒绝后下一项标题。
- 键盘 Escape 自动化因目标窗口未获得系统焦点而被拒绝，未记为通过；截图同样处于非活动外观，未将主按钮蓝色记为最终 App 的视觉验证。未覆盖 macOS 15、深色外观或真实系统写入。
- `git diff --check`：通过。

## 维护检查

README: updated，中英文同步 sheet / 独立 alert 的适用范围。AGENTS.md: unchanged，已有 App 指令链接设计系统，模块边界与开发命令没有改变。

本地构建、依赖与回归产物沿用现有 `build/`、`dist/`、`node_modules/`、`.build/` 忽略规则。并行任务的提醒卡片与日期选择器修改由其独立提交，本次只提交弹窗相关改动。
