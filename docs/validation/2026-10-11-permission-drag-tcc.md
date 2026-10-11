# 屏幕录制与辅助功能授权修复

日期：2026-10-11。

## 根因

- Asky 使用 ad-hoc 签名，TCC 以 cdhash 记录授权。本机 `TCC.db` 中 `app.kulahere.KulaHere` 的屏幕录制与辅助功能条目分别为 `cdhash 5cb31354…`、`ea38bb63…`，均为开启状态；正在运行的 `/Applications/Asky.app`（0.0.4）cdhash 为 `881d3f9c…`，`codesign -R` 验证两条要求均不满足。因此系统设置显示开关已开，Asky 读到的仍是未授权。
- 列表中已有同 bundle ID 的旧条目时，系统设置不接受再次拖入同名应用，表现为“拖了不给授权”。
- 屏幕录制授权只在进程重新启动后生效，系统随即提示重启；旧流程不提供重启，也只会在状态变为已授权后才关闭面板，导致“重启了也没完成”和面板卡住。

## 改动

- ToolService 新增 `resetAuthorization`：未授权时用 `tccutil reset <服务> app.kulahere.KulaHere` 只清除本应用该项条目；随后 `registerForAuthorization` 让当前进程把自己加入列表，条目签名与运行中的构建一致。拖拽卡片仍作为列表中没有 Asky 时的备用方式。
- 屏幕录制：开关打开后不再直接关闭面板，改为显示“重新启动 Asky”，通过既有安装重开助手在退出后重新打开。
- 辅助功能：拖入被接受但 3 秒后仍未生效时，卡片回位并提示重试。
- 已授权时的“重新授权”不重置，保持原流程。

## 实际验证

- `cd Packages/KulaCore && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：全部通过，含新增 `SystemPermissionTests` 用例。
- `xcodegen generate`；`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Asky.xcodeproj -scheme Asky -configuration Debug -derivedDataPath build/DerivedData build`：BUILD SUCCEEDED。
- `python3 App/Tests/run-settings-regression.py`：通过；用替身注入 reset/register，确认首次授权各调用一次、重新授权不调用。
- `tccutil reset Accessibility app.kulahere.settings-regression`：退出码 0，确认无需管理员权限即可清除单个应用条目。

## 未验证

未在真实 TCC 中走完新构建的授权与重启流程，需安装新构建后手动确认。ad-hoc 签名下每次更新都会改变 cdhash，更新后需要重新授权；彻底避免需使用固定的 Developer ID 签名。
