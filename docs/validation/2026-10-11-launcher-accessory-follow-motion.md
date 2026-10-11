# 搜索框按钮跟随动画

- 右侧筛选按钮先出现，左侧固定按钮延迟 35 ms；分别从右侧 28 / 56 pt 处滑入，随搜索框缩短淡入并轻弹至原尺寸。
- 出现时增加一次 1 pt 白色边缘亮光，峰值不透明度 0.32，随后消退。辅助功能“减少动态效果”禁用滑动、弹簧和亮光；装饰层不参与点击。
- 保持原有按钮尺寸、总宽度、搜索框 120 ms 缩短与输入时 180 ms 展开。尝试延长缩短至 220 / 180 ms 时，清空后输入宽度及时恢复的回归失败，已恢复原值；最终检查通过。
- 实际执行：KulaCore 的 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 通过；`xcodegen generate` 与 README 中的 Debug `xcodebuild` 通过。
- 实际执行：`python3 App/Tests/run-launcher-window-regression.py --accessories` 在 Aqua / Dark Aqua 均通过，覆盖清空恢复、筛选、菜单画布、输入位置及固定 / 失焦 / Escape。
- 使用最新源码编译的实际 LauncherPanel 录制出现、输入、清空过程；本地录制保存在被现有 `build/` 规则忽略的 `build/animation-follow/`。检查了滑入方向、轻弹、最终圆形位置与边缘亮光；未实测系统减少动态效果设置。
- README: unchanged：本次只调整已有按钮的动画表现，使用流程、命令与能力不变。
- AGENTS.md: unchanged：没有新增模块边界、命令或持久开发规则。
- 本次未提交：LauncherView 原先已有未提交的按钮 / 玻璃 / 窗口改动，本次动画依赖这些改动，无法从 HEAD 独立提交完整可构建的变更；保留原有工作区与索引。

## 后续统一提交检查

- 用户明确要求将本次动画与工作区未提交改动一起提交。统一包含筛选 / 固定、原生玻璃、外部点击关闭、翻译、回归和验证文档；此前各记录的未提交说明保留为执行历史。
- 复用本会话已通过的 KulaCore 测试、工程生成、最终 Debug 构建及浅色 / 深色按钮回归；源码未再改变。
- 重新编译并运行 README 的外部点击回归：通过。运行最新源码编译的 LauncherWindowRegression 默认完整原生回归：Aqua / Dark Aqua 通过。
- `plutil -lint` 检查两份 Launcher.strings：通过。`git diff --check`：通过。
- 剪贴板完整回归在既有验证记录中仍有记录数量断言失败，未将其标记为通过；本次提交检查未重新执行该项。
- README 已有的中英文改动覆盖使用流程与回归命令，无需额外修改。AGENTS.md 未改变：没有新的架构边界或持久开发规则。
- 本地产物继续由既有 `build/` 规则忽略，本次只做本地 Git 提交。
