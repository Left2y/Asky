# 可配置剪贴板保留时间

## 行为

- 设置 › 剪贴板新增“历史保留时间”：8 小时、1 天、3 天、7 天、30 天，默认 3 天。
- 新字段为可选小时数；旧设置与非法数值回退 3 天，保留其他已有设置。
- 列表、卡片、搜索及自动清理使用所选期限；到期记录立即退出检索，旧版固定记录同样遵循期限。
- 启动时及监控器运行期间约每分钟清理；检查放在剪贴板变化判断之前，因此没有新复制也会清理。修改期限时立即按新值清理。
- 删除过期历史时同步删除全文索引，仅移除自有原图与缩略图，不删除文件历史所引用的原始文件。设备休眠或应用退出时不承诺准时从磁盘删除。

## 已执行验证

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：296 项测试通过；覆盖五个期限的过期边界、清理前检索过滤、旧版固定记录、图片清理路径与文件原路径保护。
- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过。
- `python3 App/Tests/check-localization.py`：148 个 Swift 源文件检查通过。

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py --clipboard-retention`：通过。实际操作五个下拉选项并重载 AppModel 确认保存，验证默认/旧版/非法设置回退、缩短期限立即清理旧版固定记录，以及没有新复制时的监控器清理。
- 已查看真实设置窗口截图：[浅色](../../build/clipboard-retention-light.png)、[深色](../../build/clipboard-retention-dark.png)。默认显示 3 days，控件与标签正常；截图为英文界面，中英文静态键与格式一致性检查通过。

## 范围

所有验证使用临时数据库，不修改现有安装的用户历史；未替换已安装版本。
