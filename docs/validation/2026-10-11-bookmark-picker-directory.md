# 书签授权目录识别修复

## 实际复现

- 用户授权后输入 Kimi 已进入书签模式，但没有结果。
- 检查已保存的文件夹授权，其目标是 Google 父目录，而非 Chrome。旧读取器只在当前目录查找 Default／Profile，因此父目录被标记为可读，但加载结果为空。
- 刚才的窗口缺少新增权限项，原因是运行的常用 DerivedData 构建早于独立验证目录中的构建。本次所有 App 构建与重启均使用 README 中的 `build/DerivedData`。
- 修正目录识别并重启后，真实 App 仍将原父目录授权判为未授权；没有将父目录授权视为 Chrome 数据访问成功，未确认其原因是签名、授权恢复还是子目录访问限制。

## 修复

- 选择器默认直接打开 Chrome 文件夹，用户无需从 Google 中再选择 Chrome。
- 读取器支持 Chrome 根目录、直接包含 Bookmarks／AccountBookmarks 的个人资料目录，以及下有 Chrome 子目录的父目录；仅识别这些已知结构，不递归搜索任意文件夹。
- 没有有效 Chrome 结构的目录返回 invalidFolder，不再显示“已授权”。
- 选择后先在后台实际读取书签；不可读或目录错误时显示提示，不保存新授权。
- 保存只读安全作用域授权。URL 作用域依然成对开启／结束；失效授权不会绕过系统访问检查。安全作用域与只读选项见 [Apple 文档](https://developer.apple.com/documentation/corefoundation/bookmark-data-creation-options)。

## 已运行

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/KulaCore --scratch-path build/BookmarkCoreTests`：通过。新增 Chrome 根目录／父目录／个人资料目录读取等价，以及无关目录被拒绝的测试通过。
- `xcodegen generate`：成功。
- README 标准 Debug 构建，DerivedData 为 `build/DerivedData`：BUILD SUCCEEDED。
- 实际重启该构建、打开“设置 › 系统权限 › Chrome 书签与链接搜索”，点击“去授权”：NSOpenPanel 的“位置”是 Chrome，授权按钮可用。没有代替用户点击授权。

用户确认授权后的 Kimi 实际结果与原进程重启恢复，在完成后补充。

## 文档维护

README 中英文同步可选目录与保存前校验。AGENTS.md 不变，继续由 ToolService 处理系统读取和文件选择。构建、日志及验证产物使用已有 `/build/` 忽略规则。
