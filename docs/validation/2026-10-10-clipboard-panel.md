# 独立剪贴板面板

日期：2026-10-10。

## 设计与行为

读取用户指定 Figma `tmVnTyCb2sz5egNQ7We9Sw` 的 `43:1253` 完整 design context 与截图，按其 900 × 244 pt 面板、12 pt 内边距、36 pt 搜索框、32 pt 操作按钮、264 × 160 pt 卡片、24 pt 卡片圆角、28 pt 来源图标、232 × 96 pt 缩略图布局实现。小屏幕按可用宽度收窄；采用项目 Theme 语义色、SF Symbols 和原生 Regular Liquid Glass，减少透明度时使用不透明背景。

壁纸、Safari 和示例照片是桌面背景、来源应用与历史内容示例，不作为产品静态素材。来源图标经 ToolService 取得真实应用图标，文字和图片使用实际历史；无临时 Figma 资源 URL，也没有使用设计截图作为 UI 素材。

- Ctrl + Option + C 切换独立面板；菜单栏提供备用入口。快捷键占用时，设置的剪贴板区域显示原因。
- 横向滚动卡片，搜索文字；↑/↓ 选择，Return 复制，Escape 关闭。
- 点击卡片复制。开始拖拽时也复制，并提供原始 NSString / NSImage 的 NSItemProvider，允许原生目标接收文字或图片；不请求自动粘贴授权。
- 悬停 300 ms 后显示独立完整预览窗，移开 200 ms 后关闭；移入预览窗保持可见。图片使用 scaledToFit，长文本可滚动与选择；窗口按当前屏幕可用边界限制位置。
- 右键固定/取消固定、删除记录。顶部图钉切换 normal/floating 窗口层级；窗口固定与记录固定各自独立。
- 面板隐藏后停止刷新，清空视图、列表和原图预览。可见时每 0.75 秒刷新最多 100 条；搜索最多 100 条，不把历史发送给模型。
- 新增 ClipboardAccess 统一承接系统剪贴板读取、来源图标、复制与拖拽载荷；现有 ClipboardMonitor 改走 ToolService。保持暂停、应用排除、敏感标记、30 天保留与固定记录策略。

## 已实际运行

1. `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：138 tests / 28 suites 通过。新增独立命名剪贴板测试，验证完整 Unicode 多行文字、图片 640 × 360 原尺寸、拖拽提供的数据类型，以及原图缺失时保留现有剪贴板。
2. `xcodegen generate`：成功。
3. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
4. `python3 App/Tests/run-clipboard-regression.py`：使用临时数据库与合成图片，实际创建原生面板；搜索、记录固定、窗口层级、删除及文件清理、预览显示/关闭与屏幕边界、隐藏后的资源释放通过。浅色、深色、图片预览和空结果截图已生成并检查，位于被忽略的 `build/clipboard-*.png`。
5. Computer Use 观察独立验证 App 的实际窗口和四张卡片；点击图片卡片后可见“已复制”反馈。输入框改用现有 AppKit LauncherSearchField，避免 SwiftUI TextField 对中文组合输入的干扰。
6. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc App/Sources/LauncherSearchField.swift App/Tests/LauncherSearchFieldRegression.swift -o build/launcher-input-regression`，再运行 `build/launcher-input-regression`：原生输入框回归通过。
7. `git diff --check`：通过。
8. 退出旧 Debug 进程并启动最新 Debug App；没有打包 Release 或安装到 Applications。

## 验证边界

Computer Use 的组合键投递没有可靠触发 Carbon 全局快捷键，不能据此宣称真实键盘快捷键已验收。拖拽载荷通过测试，但跨应用完成真实拖放、鼠标悬停的完整进入/离开路径、跨显示器/全屏桌面以及实际桌面玻璃合成仍需现场验收。预览的程序触发、比例与位置已验证，不等同于鼠标路径验收。未向其他应用粘贴个人历史，也未调用模型。

README 已同步中英文用法与原生回归命令。AGENTS.md 沿用已有系统操作边界和检查命令，本次没有新增稳定规则。构建、截图和临时验证 App 复用现有 `build/` 忽略规则。
