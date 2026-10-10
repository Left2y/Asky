# 搜索弹窗滚动穿透修复

日期：2026-10-10。

## 复现与修复

上次回归直接调用弹窗内部的滚动路由，没有检查 WindowServer 是否先把事件发给了背景应用。

本次启动独立进程的原生可滚动背景窗口，再显示真实搜索弹窗，通过系统投递滚动事件。修复前，搜索列表偏移保持 200 pt，背景应用偏移从 200 pt 变为 93 pt，复现了穿透。

玻璃背景原本使用 `.allowsHitTesting(false)`，让本应属于搜索外壳的区域不能接收鼠标交互。本次保留玻璃背景命中，并用外壳形状声明完整内容命中区域，覆盖输入区、结果行和空白边距。边框与外部阴影仍仅负责绘制。继续使用原有非激活 NSPanel，不改变应用激活行为。

## 已运行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（Packages/KulaCore）：130 tests / 27 suites 通过。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `python3 App/Tests/run-launcher-window-regression.py`：浅色／深色各验证行单位、像素单位在结果行、输入区、空白边距的系统事件投递，共 12 次。每次搜索列表实际偏移改变，独立背景应用偏移保持 200 pt。原有键盘导航、输入焦点、文本和窗口尺寸回归通过。
- `git diff --check`：通过。

## 验证范围

滚动事件由 CGEvent 经系统投递，未直接指定目标应用或调用内部路由来替代穿透检查。背景窗口为独立测试进程，不使用个人数据。测试使用已有的输入事件投递权限，不自动请求授权。实体触控板连续手势与惯性仍未人工验收。
