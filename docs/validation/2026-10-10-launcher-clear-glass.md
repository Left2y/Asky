# 搜索浮窗玻璃通透度修复

## 原因与修改

用户提供玻璃参数截图：Light -45° / 80%、Refraction 50、Depth 40、Dispersion 48、Frost 50、Splay 32；Fill 为 background，Stroke 为 border / Center / 1 pt。

原搜索外壳在 70% 语义背景填充上使用 Regular Liquid Glass。独立透明窗口对比确认，Regular 进一步压低背后色块与轮廓的可见度，浅色模式呈现过强磨砂感。

外壳改为 Clear Liquid Glass，保留 background 的 Light white70 / Dark black70、1 pt 语义边框、圆角及外部阴影。材质仍只作用于背景，输入和结果内容独立绘制；不使用 Luminosity 混合。减少透明度时仍使用不透明语义背景与 identity 材质。

原生实现是视觉近似，不宣称逐项复现 Figma 的折射、深度、色散、磨砂和铺展数值。公共 API 依据：[Apple Glass.clear](https://developer.apple.com/documentation/swiftui/glass/clear)。

## 已运行检查

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：128 项测试、27 个 suites 通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `python3 App/Tests/run-launcher-window-regression.py`：浅色、深色模式通过。连续输入、首批结果、列表收缩和清空时输入框漂移均为 0 pt。
- 真实窗口合成对比：临时测试进程运行修改前与修改后的实际 LauncherController / LauncherView，使用隔离数据库和模拟结果，在独立 AppKit 背景窗口上叠放两个透明 NSPanel。系统屏幕截图中左侧为 Regular，右侧为 Clear；浅色、深色均确认背景色块可见，文字与边框保留，无内容自身重影。截图留在本地忽略目录 `build/validation/launcher-glass-light.png` 与 `build/validation/launcher-glass-dark.png`。

## 范围与交付

临时探针已关闭。未重启用户正在运行的 App，未安装或打包发布版本；新材质需要退出旧进程并打开新 Debug 构建才生效。减少透明度分支保留，未切换用户系统设置做实测。Figma 参数的像素级等价尚未验证。

README 已同步中英文玻璃层说明。AGENTS.md 的模块边界与验证规则未改变，保持不变。修改前已有的八行高度、滚动裁切及其 README 内容保留，不纳入本次提交。
