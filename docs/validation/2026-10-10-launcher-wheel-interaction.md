# 搜索滚轮与触控板交互修复

日期：2026-10-10。

## 改动

- 搜索面板在窗口事件入口将输入框和结果区域的滚动事件转交原生结果滚动容器，避免输入编辑器或结果行消费手势；原样转发事件，保留精细增量、阶段与惯性信息。
- 阴影区域不拦截滚动；滚动不改变输入文本、键盘选择或输入焦点。
- 将结果分区的外层惰性布局改为普通布局，让屏外行的定位锚点存在，修复键盘选择后未滚入视野的问题。搜索源合并结果受现有数量限制。
- README 中英文同步说明滚轮、触控板与键盘导航行为。

## 已运行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：130 tests / 27 suites 通过。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `python3 App/Tests/run-launcher-window-regression.py`：浅色和深色通过。合成行单位与像素单位滚动事件，在输入框和结果区分别验证正反向滚动，读取实际原生滚动容器偏移；验证输入文本、焦点、选择保持，以及键盘将屏外文件结果滚入视野。原有窗口高度与输入稳定性检查通过，输入漂移 0 pt。
- `git diff --check`：通过。
- 退出旧 Debug 进程并重新打开新 Debug 构建；确认新进程运行。

## 验证边界

原生回归运行真实搜索面板和 AppKit 滚动容器，使用合成事件与临时数据库。没有实体鼠标、触控板手势或惯性操作验收。GUI 自动化未取得实际应用搜索窗口；不将其记为真实手势通过。未打包 Release 或安装应用。
