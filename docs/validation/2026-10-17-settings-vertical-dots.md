# 设置更多操作图标

设置里的别名与快捷指令、已安装插件菜单统一使用 MingCute `more_2` 竖向三点，无外圈。图标保持 15pt、secondary 颜色与原生菜单行为。两处共用 `SettingsMoreMenu`：28pt 图标按钮区域、6pt 圆角，悬停使用现有 `interactionHover` token，移出恢复透明；禁用时不显示悬停底色。新增 `ellipsis.vertical` 语义映射，并同步图标清单与矢量资源；资源来自清单固定的上游版本 `ca98bb55513a22ff0dab713aaf7870b512944653`。

实际执行：

- `python3 scripts/import-mingcute-icons.py /tmp/asky-mingcute-upstream`：通过，固定版本校验成功。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- 在 `Packages/KulaCore` 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --preview --plugins --plugin-icons`：启动新构建的设置预览，使用测试插件数据；已目视确认两行插件均为无外圈的竖向三点，点击首行可展开更新、回退、查看项目与卸载菜单，未执行菜单项。
- 别名列表的图标调用已同步替换；预览中无别名数据，因此未声称该列表完成实际行级视觉验收。

README: unchanged — 小型图标外观调整，现有 MingCute 说明与开发命令仍准确。

AGENTS.md: unchanged — 未改变开发流程、模块边界或持久指令。

悬停补充：再次执行 XcodeGen、Debug 构建与核心 Swift 测试，通过。首次补充构建遇到其他并行构建占用 build.db，结束后重试通过。

最终使用独立的 `build/DotsHoverRegression.app`（由原设置预览脚本生成的临时 runner 构建，独立 bundle ID）检查新版共享图标按钮：插件行竖向三点显示正常，菜单展开和收起正常。悬停背景逻辑已接入；自动化接口没有独立 move/hover 动作，未将纯悬停截图对比记为通过。
