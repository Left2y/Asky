# 剪贴板卡片拖拽兼容飞书等目标

## 问题

剪贴板卡片拖到输入框只有微信能接收，飞书等应用无反应。

## 原因

- 原实现用 SwiftUI `.onDrag` 返回 `NSItemProvider`，拖拽板上只有延迟承诺的数据。飞书等 Chromium/Electron 应用在拖入时只读取立即可用的 `public.utf8-plain-text` 或真实文件 URL，不会解析 NSItemProvider 承诺，因此拒绝放下。
- 图片原图以无扩展名的 `.img` 存储，即使提供文件 URL，目标也无法按扩展名识别为图片。

## 修改

- `ClipboardAccess.dragItem` 生成立即写入数据的 `NSPasteboardItem`：文字写 `public.utf8-plain-text`；图片导出为临时目录下 `<id>.png`，同时写 `public.file-url` 与 `public.png`。
- 剪贴板卡片改为 AppKit `beginDraggingSession` 发起拖拽，拖拽图像取卡片区域快照，取消时回到原位；开始拖拽时仍复制到系统剪贴板。

## 验证

- `swift test --filter ClipboardAccessTests`：3 项通过，覆盖文字载荷、原图缺失、无扩展名原图导出为 640 × 360 PNG 文件 URL 与 PNG 数据。
- Debug 构建通过。飞书、浏览器、微信的真实拖放需现场验收。
