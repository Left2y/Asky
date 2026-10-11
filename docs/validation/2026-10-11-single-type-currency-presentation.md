# 单一类型标题与汇率静态展示

日期：2026-10-11

- 结果列表以实际结果类别决定是否显示分类标题；末尾「询问 AI」备用动作不计入类别数量。只有一种实际类型或只有 AI 时，隐藏所有分类标题，且不保留标题高度。两种以上实际类别沿用分组标题。
- 汇率行取消选中／悬停背景，且不再添加辅助功能 selected trait；点击复制和原有回车复制路径保留。其他类型的高亮保持原样。

已执行：

1. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：全部测试套件通过。
2. `xcodegen generate`：成功。
3. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
4. `python3 App/Tests/run-launcher-calculation-regression.py` 编译成功；首轮原生运行未收到预期计算输入，calculator completion 检查失败。随后单独重新运行编译产物 `build/launcher-calculation-regression`，Aqua 与 DarkAqua 检查全部通过。
5. 人工查看新生成的 `build/currency-NSAppearanceNameAqua.png`、`build/currency-NSAppearanceNameDarkAqua.png`：分类标题消失，人民币首行没有选中背景。悬停通过始终清空背景的 SwiftUI 分支禁用；未单独录制真实鼠标悬停检查。
6. `git diff --check`：通过。

原生窗口由独立回归进程创建，使用固定汇率缓存；未重启用户已运行的应用，未打包或安装。构建截图继续使用已有 `build/` 忽略规则。

README: unchanged；修复已有展示规则，不改变使用方法、依赖或开发命令。AGENTS.md: unchanged；没有新开发规范或模块边界。只隔离本次标题判断、汇率高亮及 selected trait 修改提交，保留同一文件中的既有计算器、汇率、翻译及其他并行修改。
