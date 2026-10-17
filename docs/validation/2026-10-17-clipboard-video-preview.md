# 剪贴板视频预览

## 修复

文件历史此前只有文件名文字预览。现在通过 ToolService 解析单个可读的本地视频文件，在列表详情与卡片悬停预览中嵌入原生 AVPlayer。默认不自动播放，点击系统控件播放；切换记录或关闭预览时停止播放并清空 player/item 释放预览资源。视频悬停窗按 16:9 分配内容高度，由系统适配实际画幅。

不复制视频数据进历史，也不改变原文件复制行为。多个文件、目录、普通文本和已丢失的原文件继续显示原有文字内容。格式解码能力由 macOS AVFoundation 决定。

## 已执行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `(cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test)`：259 个测试通过，包括视频文件筛选、非视频/目录/多文件拒绝和源文件移除。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --video-preview`：通过。生成真实 H.264 MP4，验证列表/悬停的播放器资源指向、readyToPlay、默认暂停、播放时间前进、切换时清空 item、关闭预览和原文件 URL 复制。
- 检查实际窗口截图 `build/clipboard-video-list.png` 与 `build/clipboard-video-hover.png`：两处均显示视频画面。使用系统窗口截图抓取合成后的视频图层，`cacheDisplay` 不包含该图层。
- 原生视频回归使用独立可执行文件与 app bundle，避免和其他剪贴板回归覆盖同一个产物；悬停检查暂时将鼠标放在卡片内，结束后恢复位置。
- `git diff --check`：通过。

## 验证边界

生成的 H.264 MP4 用于原生窗口回归，不能代表截图中的微信源文件或所有视频编码；未在微信客户端中重新复制该文件。未替换已安装应用，未发布版本。
