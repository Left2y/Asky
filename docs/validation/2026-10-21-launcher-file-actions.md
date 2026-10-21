# 启动器文件更多操作验证

日期：2026-10-21

## 变更

文件来源的结果（含文件夹）增加“复制文件名” `⌘⇧.` 与“展示文件信息” `⌘I`，菜单关闭时也可使用快捷键。复制文件名包含扩展名，保留面板、搜索词和选择；文件信息通过 ToolService 向访达发送进程内 Apple Events，成功后隐藏启动器，失败时显示系统错误。应用来源的结果保持原有操作。

## 实际运行

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，含中文、空格、引号及多重扩展名的文件名复制检查，以及无效 URL 不覆盖剪贴板检查。
- `python3 App/Tests/check-localization.py`：通过，中英文键一致。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --action-bar`：首次运行在 Cmd K 打开断言处失败；检查模式另一次运行因查询在加载中被清空失败。使用编译好的 `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression --action-bar` 重跑通过 Aqua / Dark Aqua。检查包含四个文件菜单项、菜单开关、文件名快捷键、菜单回车复制文件名、文件和路径复制、查询与选择保留。已查看本次生成的深浅色实际窗口截图，两项文字和快捷键未被截断。
- 使用与 ToolService 相同的访达 AppleScript，通过 `osascript` 对仓库 `README.md` 打开简介窗口；通过原生辅助功能树确认窗口标题为 `“README.md”简介`，随后关闭验证窗口。

## 验证边界

访达简介脚本及菜单展示已验证；未在签名后的 Asky 主应用中实际触发 `⌘I` 并验收首次自动化授权流程。原生回归运行输出已有沙箱扩展及 Swift 编译警告，重跑退出码为 0。

## 文档检查

README 中英文已同步两项操作及快捷键。现有模块与系统操作边界不变，AGENTS.md 无需修改。构建、回归与 SwiftPM 产物沿用已有忽略规则。
