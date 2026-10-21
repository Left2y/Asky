# 个人记忆使用原生应用图标

- 个人记忆不再直接缩放 `AskyLogo` 静态 PNG。通过 ToolService 读取当前应用包的系统图标，与其他应用来源共用原生图标路径，保留系统圆角、留白及投影。
- 设置回归包同步携带 `AskyNative.icns` 与图标元数据，新增 `--sources-only` 来源页检查；README 中英文同步命令。
- `xcodegen generate`、README Debug `xcodebuild` 通过：`build/memory-native-icon-build.log`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 通过，43 tests / 10 suites：`build/memory-native-icon-core.log`。
- 完整设置回归失败于智能配置 MCP 复选框布局断言；未将其记为通过。首次来源页回归又遇到并发新增窗口类与修改 `Contracts.o` 的编译冲突。
- 使用 HEAD 的 App 源码、当前 DataSourceIcon、仅增加来源页入口的回归文件，以及复制后的 Debug 产品建立隔离快照；来源页回归通过：`build/memory-native-icon-isolated.log`。快照位于 `build/memory-icon-snapshot/`，不修改其他工作区任务。
- 已目视检查隔离原生窗口生成的浅色 `build/memory-icon-snapshot/build/settings-light-sources.png`：图标圆角及投影正常，未见截图中的突出方边。深色截图生成成功，但延续了上一轮的滚动位置，记忆行不在画面内，不能据此声称完成深色图标目视验收。
- 日志、产品、快照与补丁均复用已有 `build/` 忽略规则，无新增忽略项。保留其他设置窗口与输入编辑相关并发修改。
- README: updated，双语新增来源页回归命令；AGENTS.md: unchanged，本次未改变模块边界、开发工具或持久约定。
