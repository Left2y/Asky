# 搜索框描边修正

日期：2026-10-10。范围：启动器搜索框外壳。

用户截图显示浅色背景上的搜索框边界不清晰。原实现只依赖 Regular Liquid Glass 自带的边缘，缺少独立描边。

## 实现

- 在玻璃层上方增加 1 pt `Colors/borderFocused` 语义描边，按外层 Light / Dark 模式解析。
- 描边向内留出 0.5 pt，避免线条被无边框窗口裁切；跟随收起胶囊和展开圆角外壳。
- 减少透明度模式保留描边；装饰层不拦截输入，也不进入辅助功能树。
- 保留现有尺寸、材质、键盘与搜索行为。

## 实际验证

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，116 项测试、23 个 suite。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：`BUILD SUCCEEDED`。
- `git diff --check`：通过。

未运行实际窗口的截图、Light / Dark、减少透明度或键盘交互验收。构建不替换正在运行的旧进程，需退出并打开新构建查看效果。
