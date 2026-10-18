#!/bin/bash
# 打开本地 Debug 构建的 Asky.app。传入 --build 时先构建最新代码。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/DerivedData/Build/Products/Debug/Asky.app"

if [[ "${1:-}" == "--build" || ! -d "$APP" ]]; then
    DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" xcodebuild \
        -project "$ROOT/Asky.xcodeproj" \
        -scheme Asky \
        -configuration Debug \
        -derivedDataPath "$ROOT/build/DerivedData" \
        -skipPackageUpdates \
        build
fi

# 已安装的正式版可能正在运行（同一 bundle id），用 -n 强制启动 Debug 副本。
if pgrep -f "$APP/Contents/MacOS/" >/dev/null; then
    open "$APP"
else
    open -n "$APP"
fi
