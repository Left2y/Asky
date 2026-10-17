# 剪贴板文件与预览图分类修复

## 修改

当剪贴板同时包含文件 URL 和位图时，以文件为准。文档、视频、文件夹和已失效路径不会被附带的图标或视频缩略图替代。单个真实图片文件仍直接读取原文件，兼容聊天应用的临时图片；没有文件 URL 时仍识别 PNG、TIFF、JPEG 等图片数据。

原有误存为图片的历史未保留原文件路径，无法自动还原，需要重新复制原文件。

## 实际验证

- 执行：`cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，退出码 0，260 个测试通过。
- 新增真实独立 NSPasteboard 回归：Markdown、PDF、MP4、MOV、文件夹和不存在的 MP4 路径分别附带 PNG/TIFF，均保留原 URL 且不生成图片记录。
- 原有聊天图片格式、临时图片删除、多文件、视频预览 URL、文件复制与拖放、敏感剪贴板测试通过。
- 系统输出包含 `sandbox_extension_consume failed` 日志，未造成测试失败。

## 运行版本与实际窗口复验

- 执行 `xcodegen generate`，再执行 README 的 Debug `xcodebuild` 命令，结果 `BUILD SUCCEEDED`。
- 终止旧 Debug 进程 PID 3119，重新启动同一路径的新构建 `build/DerivedData/Build/Products/Debug/Asky.app`，新进程 PID 5846；签名时间为 2026-10-17 17:05:23。
- 通过 Orca computer-use 在访达中分别选中并按 Command-C 复制 `文件分类验证.md`、`视频分类验证.mp4`，通过 Control-Shift-C 打开实际应用的剪贴板列表。
- 检查实际窗口截图：左侧分别显示完整的 `文件分类验证.md`、`视频分类验证.mp4`；视频右侧显示原生播放器及测试视频画面，不再显示“图片”。只读检查历史中这两条记录均为 `kind=file`，保存真实文件路径。
- 截图证据保存在本机 `/tmp/asky-clipboard-ui.json` 与 `/tmp/asky-video-ui2.json` 所指向的 Orca 临时截图路径，不纳入 Git。
- 检查来自访达的两条旧图片记录：均没有文本或原文件路径，无法可靠迁移；保留记录，需要用户重新复制原文件。
- 测试文件位于已忽略的 `build/clipboard-classification-check/`，保留以便重复验证。
