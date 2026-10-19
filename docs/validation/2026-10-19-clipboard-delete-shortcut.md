# 剪贴板删除记录快捷键

- 卡片和列表支持 `⌘⌫` 删除当前选中记录，列表“更多”菜单显示对应键帽。
- 普通退格及带额外修饰键的组合不触发记录删除；忽略按键重复，空选中项安全返回。
- 删除关闭更多菜单，保留面板及搜索词，复用既有删除流程。

已执行并通过：

```sh
cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
# 以下在仓库根目录执行
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-clipboard-regression.py --delete-shortcut
```

原生回归使用临时数据库，通过真实剪贴板面板的 `sendEvent` 路径覆盖两种布局、菜单开启、重复事件和空选中项；通过处理器检查普通退格与额外修饰键不触发删除。此次未进行菜单视觉验收或物理键盘操作检查。

README 中英文已同步快捷键；AGENTS.md 无需更新，未改变架构或开发流程。构建及回归产物沿用现有 `build/` 忽略规则。
