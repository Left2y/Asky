# 搜索结果内容上移修正

日期：2026-10-18

用户确认移动的是结果内容。原因是 ResultList 入场显式设置了从下方 6 pt 回到 0 的 offset。删除这条 offset，保留原位 180 ms 淡入与外壳展开；减少动态效果仍为 100 ms 淡入。

实际检查：
- `xcodegen generate` 与 README 的 Debug `xcodebuild`：BUILD SUCCEEDED，日志 `/tmp/asky-result-fade-build.log`。
- KulaCore `swift test`：全部成功退出，日志 `/tmp/asky-result-fade-core.log`。
- `codesign --verify --deep --strict`：成功退出。
- 退出旧 Debug 进程 4508 并启动新构建，实际进程读回 PID 8141，路径为仓库 `build/DerivedData/Build/Products/Debug/Asky.app/Contents/MacOS/Asky`。
- GUI 连接可识别新进程，但未获得可见搜索结果窗口；本次未重复声称完成动效目视验收。

保留并发文件夹导航改动，仅提交本次 offset 删除与相关文档。现有 README 对原位淡入的说明仍准确，AGENTS.md 的边界、构建与检查规则未改变。
