# 插件图标与列表布局

- 官方与已安装插件显示 36 pt 图标。清单可选 `icon` 指定插件内本地图片；旧清单兼容。优先作者图片，其次官方插件对应本机应用图标，最后内置蓝色玻璃拼图图标。
- 图片经 ToolService 读取，拒绝目录越界、绝对路径、逃逸软链接与超过 2 MiB 的文件；读取失败或图片无法解码时回退。
- 已安装列表采用两行布局：图标、名称、版本与右侧开关；下行仓库地址与小尺寸操作按钮。开关隐藏可见标签，保留辅助功能名称。

## 实际检查

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`（在 `Packages/KulaCore`）：通过，包含旧清单兼容、图片读取、越界、软链接、文件大小与未知插件检查。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/run-settings-regression.py --plugins-only --plugin-icons -AppleLanguages '(zh-Hans)'`：使用临时 LocalStore 的原生窗口检查作者图片、缺图回退、Orca / 飞书本机图标，通过，输出浅色与深色快照至忽略的 `build/`，均已查看；通过 computer-use 检查重新打开的原生预览窗口，确认最终两行布局。不安装真实插件。

## 图标资产

通过内置 imagegen 生成，参考现有 Link / Bookmark 图片。提示词：白色圆角方形底板，居中蓝色透明液态玻璃拼图块，保持参考图标的留白、圆角和高光，无文字，底板之外透明。

资源位于 `App/Assets.xcassets/Plugin.imageset/`，分别为 32 px / 64 px PNG。源生成图片保留在工具输出目录，项目不依赖该目录。
