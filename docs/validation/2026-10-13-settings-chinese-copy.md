# 设置页中文末尾句号调整

- 范围：设置各分栏及关联授权、模型检查、更新提示的 44 条中文显示文案
- 仅调整 zh-Hans 本地化值，保留本地化键、英文翻译和句子中间的标点；补齐 8 条缺失的中文翻译
- 实际通过：`plutil -lint App/Resources/zh-Hans.lproj/Localizable.strings`
- 实际通过：`xcodegen generate`
- 实际通过：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`
- 实际通过：检查上述 Debug 包内 zh-Hans 资源，44 条对应值全部存在且不以 `。` 或 `.` 结尾
- 实际通过：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 App/Tests/run-settings-regression.py -AppleLanguages '(zh-Hans)'`，原生浅色/深色设置快照、授权生命周期和拖拽恢复检查通过
- 人工查看本次生成的浅色/深色模型页和浅色数据来源页快照，确认说明文案末尾无句号
- 未修改 Swift 源码，未运行 KulaCore swift test；未触发真实网络错误或真实更新安装，外部服务和系统返回的动态错误文本不属于此次静态文案调整
- README 与 AGENTS.md 无需本次修改：构建命令、用法和架构均未变化
- 原工作区已有模型设置等未提交改动；本次新增与其相关的翻译，未自动创建混合提交。构建与快照由现有 `build/` 忽略规则覆盖
