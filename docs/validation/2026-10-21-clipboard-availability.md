# 剪贴板失效原件过滤

## 问题与修复

历史文件只保存原路径；过去列表、搜索不检查原件，用户复制时才会发现原件已丢失。缩略图仍在的图片也可能已经失去原图。

- ToolService 统一检查文本、整组文件的可读性和图片原件的解码能力；图片检查按修改时间与大小缓存，最多保存 256 个结果，不缓存解码后的图片。
- 历史列表、卡片及搜索排除不可用记录，再应用结果数量限制。无搜索词时分批读取，每批 128 条。
- 保留数据库记录与原始文件；原路径恢复可用后重新显示。仍遵循现有保留期限与容量清理策略。
- 刷新时保留当前选中记录；若复制前原件刚好失效，立即刷新并保留系统剪贴板原有内容。
- 采集时拒绝已经不可读的文件引用。

## 已执行检查

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：293 项通过。新增回归覆盖 260 条失效记录后的有效内容、原文件恢复、部分文件丢失的多文件组、空文本、损坏及缺失原图、缩略图残留。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/check-localization.py`：148 个 Swift 源文件检查通过。

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --availability`：通过。真实窗口覆盖列表与卡片的隐藏/恢复、选中项保持、复制瞬间失效且保留剪贴板、主搜索过滤后截取结果，以及监控器拒绝失效文件引用。
- 已查看实际窗口截图：[列表](../../build/clipboard-availability-list.png)、[卡片](../../build/clipboard-availability-cards.png)，失效文件未显示，有效文本正常显示。本次截图为深色外观。
- 窗口回归第一次编译与后续 Debug 重建共享产物发生冲突；等待构建完成后重新运行，最终退出码为 0。

## 边界

这次通过独立临时数据验证，不删除或迁移用户现有历史。文件恢复是指原路径重新可读；不会追踪文件移动后的新路径。真实第三方应用中的自动粘贴及可移除磁盘断开/重连未在本次实测。
