# Links and bookmarks in the app group

Date: 2026-10-10.

- Ordinary search maps app, link, and bookmark sources to one APP 应用 display group. Original sources, actions, row indexes, and ordering are retained. Header count and list height use the combined groups.
- Restarted the actual Debug app and searched `kimi`. The screenshot shows Kimi, KimiCU, 打开链接, and 搜索书签 under one APP 应用 heading, followed by the file group. No separate link or bookmark heading appears. No URL was opened or bookmark search executed.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` in Packages/KulaCore: 130 tests in 27 suites passed.
- `xcodegen generate`: passed.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KulaHere.xcodeproj -scheme KulaHere -configuration Debug -derivedDataPath build/DerivedData build`: BUILD SUCCEEDED.
- README: Chinese and English grouping descriptions updated. AGENTS.md: unchanged; commands, architecture, and persistent constraints are unchanged.

Logs and screenshots remain in the system temporary directory. Build output uses the existing build/ ignore rule. Other worktree changes predate this task; only grouping and its documentation are included in this task commit.
