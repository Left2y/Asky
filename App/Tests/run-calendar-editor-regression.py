#!/usr/bin/env python3
"""Build the actual calendar editor; --preview uses sample calendars and never saves events."""
import os
import platform
import plistlib
from pathlib import Path
from regression_resources import copy_core_resources
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
derived = Path(os.environ.get("ASKY_DERIVED_DATA", root / "build/DerivedData"))
products = derived / "Build/Products/Debug"
if not (products / "Scheduler.o").exists():
    sys.exit("Build the Debug app with the README command first.")
environment = os.environ.copy()
environment.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], env=environment, text=True).strip()
command = ["xcrun", "swiftc", "-parse-as-library", "-whole-module-optimization", "-swift-version", "6", "-D", "DEBUG",
           "-sdk", sdk, "-target", platform.machine() + "-apple-macos14.0", "-I", str(products),
           "-external-plugin-path", "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins#/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server"]
for path in sorted((derived / "Build/Intermediates.noindex/GeneratedModuleMaps").glob("*.modulemap")):
    command += ["-Xcc", "-fmodule-map-file=" + str(path)]
for relative in ["swift-cmark/src/include", "swift-cmark/extensions/include"]:
    command += ["-I", str(derived / "SourcePackages/checkouts" / relative)]
# Compile the actual shared UI components and their dependencies, just like the reply regression.
for path in sorted((root / "App/Sources").glob("*.swift")):
    if path.stem != "AskyApp":
        command += [str(path)]
command += [str(root / "App/Tests/CalendarEditorRegression.swift")]
command += [str(path) for path in sorted(products.glob("*.o"))]
bundle = root / "build/CalendarEditorRegression.app/Contents"
(bundle / "MacOS").mkdir(parents=True, exist_ok=True)
(bundle / "Resources").mkdir(exist_ok=True)
copy_core_resources(products, bundle / "Resources")
executable = bundle / "MacOS/CalendarEditorRegression"
command += ["-lsqlite3", "-o", str(executable)]
subprocess.run(command, env=environment, cwd=root, check=True)
for name in ["Assets.car", "AskyNative.icns"]:
    shutil.copy2(products / "Asky.app/Contents/Resources" / name, bundle / "Resources" / name)
with (bundle / "Info.plist").open("wb") as output:
    plistlib.dump({"CFBundleExecutable": "CalendarEditorRegression", "CFBundleIdentifier": "app.asky.calendar-editor-regression",
                  "CFBundleName": "Asky 日程配置预览", "CFBundleIconFile": "AskyNative", "CFBundleDevelopmentRegion": "zh-Hans",
                  "CFBundlePackageType": "APPL", "LSUIElement": True}, output)
subprocess.run(["codesign", "--force", "--sign", "-", str(bundle.parent)], check=True)
subprocess.run([str(executable), *sys.argv[1:]], env=environment, cwd=root, check=True)
