# 应用搜索图标

应用搜索入口的 `app.badge` 映射替换为用户指定的 MingCute `classify_add_2_line`（上游 regular/classify_add_2.svg），沿用现有蓝色底板、白色模板、尺寸与圆角。资源来自清单固定版本，Swift 映射与导入清单同步。

实际验证：

- `python3 scripts/import-mingcute-icons.py /tmp/asky-mingcute-upstream`：通过，固定版本校验通过。
- `xcodegen generate` 与 README 的 Debug `xcodebuild`：通过，日志 `/tmp/asky-classify-icon-build.log`。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，日志 `/tmp/asky-classify-icon-tests.log`。
- 使用实际 `LauncherFunctionIcon`、`MingCute` 和新构建 Assets.car 的原生 NSWindow 预览，查看浅色与深色截图：`build/application-search-icon-NSAppearanceNameAqua.png`、`build/application-search-icon-NSAppearanceNameDarkAqua.png`，首枚应用搜索图标显示三格与加号。
- 预览和构建产物复用现有 `build/` 忽略规则，未替换已安装应用。

README: unchanged，图形替换不改变使用方式或既有图标规范。

AGENTS.md: unchanged，无新增命令、模块或持久规则变化。
