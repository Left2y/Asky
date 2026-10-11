# 计算器图标替换

日期：2026-10-11

- 输入来源：用户提供的 `/Users/niallyoung/Downloads/Calender.png`。
- 原图虽然包含 alpha 通道，但 alpha 全为 255；白色背景不是透明背景。
- 使用内置 imagegen 去除外部白底，保留蓝色玻璃计算器及四个运算符。提示词：背景提取；仅移除计算器轮廓之外的白底，输出真实透明 PNG；保留蓝色玻璃轮廓、空显示屏、2×2 按钮、加减乘等号、颜色和高光，不重新设计，不添加白色方形底板；居中并保留少量透明边距。
- 使用 sips 为资源目录准备居中的正方形画布及 1x（64×64）、2x（128×128）图片，保留 alpha。资源位于 `App/Assets.xcassets/Calculator.imageset/`。
- 计算器结果使用 `Image("Calculator").resizable().scaledToFit()`，与链接一样放入现有 32 pt 图标位置，以透明独立轮廓展示。

验证命令：

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore`：全部套件通过。
- `xcodegen generate`：成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- 图片 alpha 检查：两份最终资源的 alpha 范围均为 0–255；人工检查 2x 图片确认透明背景及蓝色计算器轮廓。

原生键入回归遇到 IMK 输入法错误，未将该次运行记为通过。为检查实际图片资源，使用当前真实 LauncherPanel / LauncherView 和临时修改的回归入口，在独立预览进程中直接设置 `1+1` 并将光标置于末尾。预览使用 Debug 编译得到的 Assets.car，临时预览目录 `build/CalculatorIconPreview.app` 使用已有 `build/` 忽略规则；不安装至 Applications，不打包 Release。

带资源的独立原生预览在 Aqua、DarkAqua 均通过检查；人工查看更新后的两张 `build/calculator-NSAppearanceName*.png`，确认蓝色计算器在实际结果行内显示、没有白色底板、大小与邻接 AI 图标一致。

README: unchanged；只替换内部图标资源，功能、使用方法与开发命令不变。AGENTS.md: unchanged；没有新增开发规范、工具链或模块边界。提交仅包含新图标资源、计算器图片分支及本记录，保留工作区既有修改。
