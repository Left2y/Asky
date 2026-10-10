# 搜索框外部阴影

日期：2026-10-10。来源：用户提供的 Drop shadow 参数截图。

## 实现

- X 0、Y 12、Blur 80、Spread 0、`#000000` 12%；SwiftUI 使用 radius 40 pt 映射 Figma 的 Blur 80，跨渲染器的模糊结果尚未视觉校准。
- 用不透明外壳轮廓生成阴影，随后挖去内部，使阴影不显示在透明区域后方，且不受背景 70% alpha 影响。
- 在透明 NSPanel 四周预留 132 pt，让阴影有完整的渲染空间；搜索框可见宽度仍为 720 pt、收起高度仍为 60 pt，原屏幕定位和展开高度限制保持不变。
- 保留主题描边与玻璃层，继续关闭矩形窗口阴影。装饰阴影不参与命中测试和辅助功能。

## 实际验证

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：116 项测试、23 个 suite 通过。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：`BUILD SUCCEEDED`。
- `git diff --check`：通过。

未进行实际窗口截图、阴影模糊匹配、Light / Dark、减少透明度或交互验收。需退出旧进程、打开新构建查看效果。
