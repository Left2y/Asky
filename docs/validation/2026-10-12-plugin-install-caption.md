# Plugin install caption removal

Removed the secondary caption row from the install section. Native Form collapses the row and its separator.

Executed verification:

- KulaCore swift test with DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer: exit 0.
- xcodegen generate: passed.
- Asky Debug xcodebuild using build/DerivedData: BUILD SUCCEEDED.
- Fresh build PID 23549 from build/DerivedData/Build/Products/Debug/Asky.app/Contents/MacOS/Asky: inspected plugin settings screenshot and AX tree. Caption and extra separator absent; repository field and install button visible.

README and AGENTS.md unchanged: this caption removal does not change usage or development policy. Concurrent font and scheduler edits excluded from this task commit. Build artifacts use the existing build ignore rule.
