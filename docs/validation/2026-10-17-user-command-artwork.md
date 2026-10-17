# 接入用户交付的 14 张网页指令图标

## 实现

使用用户本轮交付的 14 张 `Command logo *.png`，覆盖对应 `Command*.imageset/logo.png`。全部原图为 99 × 99 px RGBA PNG；复制后逐项比较 SHA-256，14 份资源均与交付文件完全相同。

共享 `CommandIcon` 统一采用 20 × 20 pt 图片画布、4 pt circular 圆角、24 × 24 pt 外部占位。所有品牌均使用原始颜色，取消 ChatGPT 的尺寸例外和 GitHub 的模板着色，不调整图片内部留白、不单独缩放品牌图案。设置页、启动器搜索范围与搜索结果共用同一组件。终端应用图标保留原有显示逻辑。

本轮使用用户交付的 bilibili 字标和京东彩色小狗 PNG；不再从之前搜集的 SVG 推导图案。

## 已运行的验证

- `xcodegen generate`：通过。
- README 中的完整 Xcode Debug 构建命令：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（`Packages/KulaCore`）：262 个 Swift Testing 测试通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py`：通过。已查看新生成的 `build/settings-light-keywords.png` 与 `build/settings-dark-keywords.png`，确认图标原色与方形圆角底板。
- 使用真实 `CommandIcon.swift`、`MingCute.swift` 和新构建的资源编译本地检查程序 `build/user-icon-canvas-check.swift`：深浅色下共 28 次检查通过。每张可见画布在 2x 下均为 40 × 40 px，alpha 横纵对称；中心像素与交付图片直接等比绘制结果一致。已查看生成的原生窗口整组截图 `build/icon-shape-gallery.png`。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --command-icons`：在原生窗口截图读取处遇到 `CommandIconsRegression Code=3`；直接重新执行生成的回归程序仍遇到同一错误。启动器自动截图检查未通过，不能由设置页与独立组件检查替代其结果。

截图、临时检查程序和构建产物沿用现有 `build/` 忽略规则；不替换已安装应用。README 的使用方式、开发命令及 AGENTS.md 的架构和验证规则不变。
