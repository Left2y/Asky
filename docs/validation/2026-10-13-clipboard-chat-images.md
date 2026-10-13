# 聊天平台图片剪贴板识别

日期：2026-10-13。

## 行为

图片与文件名文本同时存在时，历史记录采用图片；单个可读取的图片文件地址在来源临时文件删除前保存原图。支持 PNG、TIFF 和声明为图片 UTI 的 JPEG 等载荷；验证图片元数据并限制为 20 MiB。多文件选择仍记录为文件，敏感剪贴板标记仍被排除。

## 实际检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，在 `Packages/KulaCore` 执行：通过。
- 同目录 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter ClipboardAccessTests`：6 个测试通过，覆盖 PNG/TIFF/JPEG 加文件名、临时 JPG 删除后原图仍可解码、多文件和敏感标记。
- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：`BUILD SUCCEEDED`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --chat-images`：通过。使用真实 ClipboardMonitor、ClipboardStore 和原生窗口；两种载荷均生成图片历史、可用缩略图，源文件删除后再次复制仍保留原始像素尺寸；历史恢复不新增文本记录。
- 已查看 `build/clipboard-chat-images.png`：两张卡片均显示图片缩略图，而不是文件名。
- `git diff --check`：通过。构建与截图复用现有 `build/`、SwiftPM `.build/` 忽略规则。

## 验证边界与工作区

这里通过构造原生剪贴板载荷验证，未在飞书、微信客户端逐一执行复制图片，因此不表示这些客户端的所有私有载荷均已验收。原来已被误记为文本或文件的历史不会自动迁移；需重新复制原图。未替换 `/Applications/Asky.app`，新代码在 Debug 构建中。

首次原生回归遇到共享 Debug 对象文件被其他构建修改，重试后解决；第一次运行的尺寸断言将 Retina 点尺寸当成像素尺寸，已修正为比较原图实际像素，最终通过。

任务开始时 ClipboardMonitor 和 ClipboardAccess 已有未提交的同问题修改；本次基于它们补充格式识别与验证。期间还有菜单栏设置等并行修改及 README 共享改动。为避免提交他人的修改或只提交不完整修复，未创建任务提交。AGENTS.md 无持久规则变化；README 和开发指南双语同步新增回归入口。
