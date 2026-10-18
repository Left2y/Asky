# 收小工具入口圆角

用户明确选择以下方快捷指令的视觉效果为参照，收小工具入口圆角。

- `LauncherIconTile.toolCornerRadius` 为 3 pt 普通圆弧；网站指令保留 4 pt，AI 保留原图与既有裁切。20 pt 底板、16 pt 工具图形、24 pt 外槽和颜色不变。
- 搜索结果、输入模式和指令设置复用 `LauncherFunctionIcon`，同时生效。
- `xcodegen generate`、README 的 Debug `xcodebuild` 通过，日志 `/tmp/asky-smaller-tool-corners-build.log`。
- 实际组件深浅色原生窗口预览通过，截图 `build/shared-icon-tiles-NSAppearanceNameAqua.png`、`build/shared-icon-tiles-NSAppearanceNameDarkAqua.png`，已检查工具圆角收小后的效果。
- 使用实际 LauncherController 与 LauncherView、隔离存储和工具/品牌结果夹具运行完整列表，深浅色检查通过，日志 `/tmp/asky-smaller-corners-list.log`，截图 `build/launcher-icon-list-NSAppearanceNameAqua.png`、`build/launcher-icon-list-NSAppearanceNameDarkAqua.png`。直接读取用户当前窗口的 CUA 调用连续超时，因此不声称已读取用户当前窗口。
- 开发版已重启到新构建，PID 84458，路径 `build/DerivedData/Build/Products/Debug/Asky.app/Contents/MacOS/Asky`；安装版未替换。
- 本轮此前的 KulaCore 全量测试存在 RealRuntimeIntegrationTests 的 running 状态与 PID 两项失败，详见 shared-icon-tile 验证记录；本次仅修改圆角参数，不将该结果记为通过。
- README: updated，中英文同步工具 3 pt 圆角；设计系统同步。AGENTS.md: updated，App 范围参数按用户最新要求改为 3 pt。
- 保留开始时的交叉暂存和未跟踪文件，未创建混合提交；产物复用既有 `build/` 忽略规则。
