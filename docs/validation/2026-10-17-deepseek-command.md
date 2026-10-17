# DeepSeek 网页指令与品牌 Logo

- 新增默认启用的 `ds 问题` 内置指令，网址为 `https://chat.deepseek.com/?q={query}`。携带问题打开网页并填入输入框，用户手动发送；不调用 Asky AI。
- 官方图标来自 `https://fe-static.deepseek.com/chat/icon-180.png`（由官网 apple-touch-icon 链接确认），随应用打包为 `CommandDeepSeek`。保留原始蓝色鲸鱼与白色底图；使用 24 pt 画布容纳官方留白，设置、输入模式和搜索结果共用 CommandIcon。
- 本轮前的真实 Chrome 测试：已登录 DeepSeek 打开上述带 q 参数的网址，输入框实际出现“请只回复：Asky测试成功”；没有发送。Gemini 同方式没有填入，豆包未登录测试没有填入，未加入这些指令。

## 实际执行

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：退出码 0，包含新增 DeepSeek 中文及 `& + # / ?` 编码回归。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DeepSeekDerivedData build`：BUILD SUCCEEDED。
- `ASKY_DERIVED_DATA=build/DeepSeekDerivedData DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-launcher-window-regression.py --command-icons`：通过浅色、深色全部指令的原生输入、空格进入、品牌资源加载、单个结果与空文本退格退出回归。旧输出中的“All eight”为历史固定文案，实际循环全部当前指令，包含 ds。
- 已查看 `build/command-icon-NSAppearanceNameAqua-ds.png` 和 `build/command-icon-NSAppearanceNameDarkAqua-ds.png`：输入图标和结果均为官方蓝色鲸鱼，原色显示，布局无裁切。

- `ASKY_DERIVED_DATA=build/DeepSeekDerivedData DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py`：通过全部内置指令的启用、禁用、候选隐藏与持久化回归，以及设置窗口浅色／深色原生回归。已查看 `build/settings-light-keywords.png` 和 `build/settings-dark-keywords.png`，DeepSeek 条目、勾选框和鲸鱼 Logo 显示正常。

构建日志和窗口截图保留在已被忽略的 `build/`，没有修改已安装的 Asky，也没有打包或发布。
