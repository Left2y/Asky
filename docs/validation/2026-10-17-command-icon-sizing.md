# 指令品牌图标尺寸修正

## 原因与修改

`CommandIcon` 原先把 ChatGPT 与 DeepSeek 都按 24 pt 绘制，其余品牌按 20 pt 绘制。ChatGPT 的 1024 px 画布中实体底板为 824 px，外围微弱阴影延伸至 882 px，DeepSeek 则没有外部透明留白，导致 DeepSeek 明显偏大。

保留共享的 24 × 24 pt 图标槽，将 DeepSeek 改为 20 pt，仅对 ChatGPT 按 `20 × 1024 / 824` 补偿透明留白。首次按阴影边界 882 px 补偿，用户反馈 ChatGPT 仍显小；再次检查 alpha >= 128 的实体边界为 `(100, 100, 924, 924)`，因此改用实体底板尺寸。品牌保持原始宽高比；YouTube 横向标识的高度自然小于方形标识。设置、搜索范围和结果共用此修正。

## 实际验证

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 `Packages/KulaCore`）：262 个 Swift Testing 测试通过。首次未指定 Xcode 的调用因 Command Line Tools 缺少 Testing 模块失败；切换完整 Xcode 后通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py`：通过。
- 已查看新生成的实际窗口截图 `build/settings-light-keywords.png` 与 `build/settings-dark-keywords.png`：DeepSeek 不再大于相邻方形品牌图标，ChatGPT 可见外框接近统一尺寸，文字和复选框对齐保持正常。

截图及构建产物沿用现有 `build/` 忽略规则。此次不替换已安装应用。
