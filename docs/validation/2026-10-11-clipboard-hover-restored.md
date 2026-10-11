# 剪贴板悬停完整预览恢复

日期：2026-10-11。

## 修改

- 卡片覆盖的 AppKit 拖拽视图同时负责悬停跟踪，使用实际视图的屏幕坐标定位预览。
- 显示延迟由 1.5 秒改为 1 秒；离开卡片或预览保留 200 ms 的交接时间。
- 使用持续有效的 inVisibleRect 跟踪区域，避免反复重建；重复进入同一卡片不重启计时。离开回调核对实际鼠标位置，旧卡片或预览初始化的离开回调不取消当前卡片预览。
- 长图居中的回归断言接受 AppKit 窗口像素取整的 1 pt 容差，失败信息保留实际窗口与锚点坐标。
- 直接调用控制器的回归清除输入焦点并将鼠标停在标题区域，避免并行桌面输入干扰；真实鼠标回归独立覆盖悬停交互。
- 测试 bundle 写入后重新签名，避免复用 bundle 时因旧签名被系统终止。

## 实际验证

- 修改前真实鼠标悬停超过 1.5 秒仍未显示，触发 `real card hover must display the full preview` 断言。
- KulaCore `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：192 项 Swift Testing 测试通过。
- `xcodegen generate` 成功，README 中 Debug xcodebuild 命令成功，最终构建 `BUILD SUCCEEDED`。
- 原生窗口 `--hover-delay`：1 秒延迟、短暂悬停取消和关闭释放通过。
- 原生窗口 `--hover-mouse`：通过 WindowServer 投递真实鼠标事件，文字/图片卡片 600 ms 不显示、移开取消、1200 ms 显示、进入预览保持、离开关闭均通过。已查看实际窗口生成的文字与图片预览截图。
- 完整原生回归：浅深色快照、搜索、固定、删除、预览定位、长图比例、长文字滚动高度及释放检查通过。
- 真实鼠标拖拽回归通过，目标文字内容及未固定面板关闭通过。

## 验证范围

工作区同时有其他启动器、阴影和拖拽改动。测试编译使用冻结的 Debug 依赖、已提交的其余 App 源码和本次悬停改动，并启用 `-whole-module-optimization -Onone`，避免并行写入源码或构建产物干扰。回归执行的是实际 ClipboardController 与 SwiftUI/AppKit 卡片窗口；App 的 Debug xcodebuild 同时验证了当前工作区集成构建。

测试图片、日志和源码快照保存在已忽略的 build/ 中。没有替换 Applications 中的安装版本。

README 中英文同步 1 秒行为和 --hover-mouse 命令。AGENTS.md 无需更新：未改变项目架构、模块边界或开发约定。
