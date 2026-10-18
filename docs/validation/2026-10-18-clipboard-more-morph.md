# 剪贴板列表“更多”同步搜索变形效果

日期：2026-10-18。

## 改动

剪贴板列表原先使用独立 `SurfacePanel` 展示更多菜单，未接入启动器的原位变形。现改为在主窗口覆盖层中绘制按钮和菜单，macOS 26+ 开启液态玻璃时共用 `GlassEffectContainer`、相同 `glassEffectID` 与 `.matchedGeometry`，180 ms smooth 展开和收回，右下角始终对齐。沿用启动器按钮样式、快捷键标签与菜单尺寸计算。菜单高度受搜索行下方可用空间约束，内容可滚动；不改动卡片悬停菜单。

保留 ⌘K、方向键、回车、Esc、选中项变化和输入变化关闭菜单的行为。窗口内点击判定包含菜单范围，防止菜单项在执行前被关闭。减少动态效果立即切换，旧系统或关闭液态玻璃保留材质回退。

## 实际验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过，日志 `build/clipboard-morph-build.log`。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，日志 `build/clipboard-morph-core.log`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --layouts --more-motion`：通过，日志 `build/clipboard-morph-regression.log`。覆盖菜单内置于主窗口、范围不越界、外壳尺寸不变、关闭前后 firstResponder 不变、键盘固定/取消固定、删除、查询变化与空结果收起，以及既有布局切换、选择、复制与持久化。
- 回归第一次运行因旧测试假定默认卡片布局而停止；实际配置 `SettingsPreferences.clipboardLayout` 默认 `.list`。已将布局测试起始卡片状态改成显式测试夹具，并更新旧配置缺省值断言后重跑通过。
- 查看浅色和深色真实窗口截图 `build/clipboard-layout-actions-menu-light.png`、`build/clipboard-layout-actions-menu-dark.png`、对应 footer 截图。菜单右下角与原按钮对齐。
- 查看 `build/clipboard-more-morph-21F8CEDE-A2C3-47F4-88B5-4E9F29D1FEDC.mov` 的 12 fps 抽帧联系表 `build/clipboard-morph-contact.png`，可见菜单连续收缩为按钮、按钮连续扩大为菜单。
- `git diff --check`：通过。

## 范围与维护

macOS 15 实机、减少动态效果及其他辅助功能显示模式未单独运行，不记为实机验证通过。测试通过后并行任务继续修改拖放置入代码，该部分不属于本次验证结论。

`README: updated`：中英文同步剪贴板列表“更多”效果与实际回归命令。

`AGENTS.md: unchanged`：现有 App 职责、构建及验证要求仍适用，无新增模块边界。

构建、截图、录屏与抽帧复用 `.gitignore` 既有 `build/` 规则，无新增忽略规则。剪贴板源码、回归文件及设计文档在任务开始前已有修改，执行期间又有并行拖放改动；本次保留所有现有工作，不创建混合提交。
