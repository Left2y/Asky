# 附件卡片样式修正

设计来源：[UploadFile 42:852](https://www.figma.com/design/tmVnTyCb2sz5egNQ7We9Sw/Asky?node-id=42-852)，并读取 42:845、42:828 确认 SF Symbols。

- 卡片主体高 52 pt，12 pt 圆角。文件图标为 24 pt text.document，置于 44 pt、8 pt 圆角、1 pt 描边底框。
- 文件名为 14/500，大小为 12/400，行高分别为 22/20 pt，左对齐，名称末尾省略，最大标签宽度 128 pt。
- 删除按钮为 20 pt，图片向右外移 6 pt，文件外移 8 pt，均向上外移 6 pt；使用语义背景与图标色。卡片预留外侧空间，附件栏高 66 pt，悬停使用 backgroundNeutralHover。
- 示例图片由实际附件缩略图提供，没有固化 Figma 的示例照片。

实际执行：

```sh
cd Packages/KulaCore
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
# 回到项目根目录
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build
```

Swift test：133 tests / 27 suites 通过。Debug 构建成功。

重启 Debug 应用后通过系统选择器添加 README.md，实际窗口截图确认文件卡片主体、图标底框、文字对齐与尺寸。未发送消息。自动化点击和拖动未捕获悬停状态，因此删除按钮的悬停显隐、点击删除、图片附件及滚动边缘状态未记为通过。

README 已同步中英文样式说明。AGENTS.md 无变化：本次不改变构建命令、模块边界或持久开发规则。
