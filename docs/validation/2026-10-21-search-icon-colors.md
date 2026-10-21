# 搜索入口图标配色

## 变更

- `ToolIconPalette` 增加绿 #28A745、青绿 #009E9A、粉 #E34F8C、靛蓝 #5856D6。
- 链接使用青绿，窗口使用靛蓝，快捷方式使用绿，快捷指令使用粉；其余入口沿用原色。
- 窗口独立于标签页映射颜色；设置、指令搜索结果及输入模式继续复用 `LauncherFunctionIcon`。
- AI 继续使用原有 `Agent` 品牌图片；图形、20 pt 底板和 5 pt 普通圆角保持原样。

## 验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：292 项 Swift Testing 测试通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --search-commands`：通过，包含指令入口、优先级、自定义触发词、Return/Space 进入与 AI 提交时机。
- 已检查新构建实际设置窗口的[浅色截图](../../build/search-commands-light.png)与[深色截图](../../build/search-commands-dark.png)：四种新底色可辨识，AI 品牌图保留，行高、图标几何与布局未变。
- `git diff --check`：通过。

## 文档与产物

- `AGENTS.md: updated`：App 作用域的旧五色限制同步为共享色板维护要求；根级说明不变。
- `README: unchanged`：仅图标底色变化，使用方法、命令与能力说明不受影响；色值记录于设计系统。
- 构建和截图产物继续由已有 `build/` 忽略规则覆盖，无新增忽略规则。
