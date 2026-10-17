# 撤回启动器悬浮操作区

按用户要求，从该功能开始完整撤回 `8433640`（引入功能）和 `59b9d79`（Clear 玻璃 / overlay 修正）。使用反向提交保留 Git 历史。

撤回后、添加本验证记录前，`git diff 9b5d015 --exit-code` 返回 0：所有受版本控制的文件均恢复到功能加入前的状态。原有访达及复制路径快捷键保留。

实际执行：

- `xcodegen generate`：通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：通过，日志 `build/revert-launcher-actions-build.log`。
- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：通过，37 tests / 9 suites，日志 `build/revert-launcher-actions-test.log`。
- `git diff --cached --check`：通过。

README.md 中英文、AGENTS.md、设计系统与开发文档随功能一起恢复。构建日志复用已有 `build/` 忽略规则。本次未运行视觉回归，不以构建成功代替视觉验收。
