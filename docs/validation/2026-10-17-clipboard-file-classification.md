# 剪贴板文件与预览图分类修复

## 修改

当剪贴板同时包含文件 URL 和位图时，以文件为准。文档、视频、文件夹和已失效路径不会被附带的图标或视频缩略图替代。单个真实图片文件仍直接读取原文件，兼容聊天应用的临时图片；没有文件 URL 时仍识别 PNG、TIFF、JPEG 等图片数据。

原有误存为图片的历史未保留原文件路径，无法自动还原，需要重新复制原文件。

## 实际验证

- 执行：`cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，退出码 0，260 个测试通过。
- 新增真实独立 NSPasteboard 回归：Markdown、PDF、MP4、MOV、文件夹和不存在的 MP4 路径分别附带 PNG/TIFF，均保留原 URL 且不生成图片记录。
- 原有聊天图片格式、临时图片删除、多文件、视频预览 URL、文件复制与拖放、敏感剪贴板测试通过。
- 系统输出包含 `sandbox_extension_consume failed` 日志，未造成测试失败。

本次仅修改核心包，不涉及 App 源码；未构建或替换已安装应用，未进行访达真实复制及窗口验收。
