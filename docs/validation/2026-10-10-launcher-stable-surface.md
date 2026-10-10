# 搜索框底色稳定性

用户反馈搜索框在绿色背景上自动变色，并明确底色应跟随亮／暗模式。原实现将 Regular Liquid Glass 直接应用于内容，材质受背后窗口影响，而原生输入和图标按系统颜色模式取色。

## 修改

搜索框移除自适应玻璃及深色 tint，使用不透明语义中性底色和局部 6% → 2% 明暗渐变，保留圆角、定向边缘高光和外部投影。浅深色继续由系统主题决定。减少透明度关闭表面渐变；提高对比度保留语义边框。此取舍取消背景透视与原生折射，以保证底色与文字对比稳定。未修改搜索行为、列表高度或书签功能。

## 实际检查

- `xcodegen generate`：成功。
- README Debug 构建命令，使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`：BUILD SUCCEEDED。
- 首次直接 `swift test` 因 Command Line Tools 缺少 Testing 模块失败；改用上述 Xcode 环境后，130 tests / 27 suites 通过。
- 原有 `App/Tests/run-launcher-window-regression.py` 实际执行失败：`initial search must finish`，初始输入位置漂移为 0 pt。未将此窗口回归记为通过，未修改与本次材质无关的搜索逻辑。
- 临时原生桌面探针使用生产 LauncherView 和 LauncherPanel、隔离数据目录，在浅色和深色下分别切换绿色、红色、蓝色背景窗口。六张桌面合成截图已生成，已人工查看浅色绿色背景及深色红色背景。比较框内 1200 × 90 像素区域，三种背景下像素完全一致；中心 RGB 浅色为 (245,245,245)，深色为 (24,25,27)。主题为探针局部环境，不改系统设置。
- 退出旧 Debug 进程并重开当前 Debug 产品，实际浮窗确认输入焦点可见、浅色底色与放大镜清晰；设置输入 Safari 后读取到结果列表，并查看展开窗口截图。未执行结果、未安装或打包 Release。

日志、探针及六张图片位于忽略的 `build/validation/`，文件名前缀 `launcher-stable-surface` / `stable-surface`，沿用 `.gitignore` 的 `build/` 规则。

README: updated，中英文同步搜索框材质。AGENTS.md: unchanged，未改变模块边界、命令或子项目结构。提交只包含本次材质及对应文档；保留已有搜索、书签、列表与 PRD 改动。
