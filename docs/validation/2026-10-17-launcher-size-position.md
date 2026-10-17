# 启动器尺寸与初始位置

- 当前 Theme 的启动器总宽原本即为 720 pt，本次保持该值；收起时搜索胶囊让出两枚圆形按钮的空间，展开后胶囊占满 720 pt。
- 搜索列表高度预算从 304 pt 调整到 380 pt（10 个行高，含分组标题）；结果较少时仍按内容收缩，长列表完整窗口为 720 × 433 pt。
- 顶部锚点由可用屏幕高度的 12% 调整到 18%，继续保持结果展开时顶部固定，并留出屏幕底部 24 pt。

## 实际检查

- `xcodegen generate`：通过。
- README 中的 Debug `xcodebuild` 命令：通过，日志 `/tmp/asky-launcher-layout-build.log`。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，日志 `/tmp/asky-launcher-layout-swift-test.log`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py`：完整回归未通过，在慢搜索等待时保持旧高度的断言失败；此前的尺寸、定位、系统滚动投递与连续输入位置检查通过，输入位置漂移为 0。未将该完整回归记为通过。
- 使用本次编译的 `build/LauncherWindowRegression.app/Contents/MacOS/LauncherWindowRegression --bottom-clearance`：重试通过，浅色/深色均实测 `(375, 341, 720, 433)`，尺寸、18% 顶部锚点、滚动和键盘导航检查通过。首次启动一次出现初始搜索等待不足的断言失败，重试结果见 `/tmp/asky-launcher-layout-sizing.log`。
- 本次回归程序 `--accessories`：浅色/深色通过，核验收起总宽 720 pt、圆形按钮、筛选、置顶、失焦与重复唤起，日志 `/tmp/asky-launcher-layout-accessories.log`。
- 已检查浅色/深色实际窗口截图 `build/launcher-sizing-NSAppearanceNameAqua.png` 与 `build/launcher-sizing-NSAppearanceNameDarkAqua.png`。

构建与截图沿用已存在的 `build/` 忽略规则；未替换 `/Applications` 下的已安装应用。
