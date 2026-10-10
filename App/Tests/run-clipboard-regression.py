#!/usr/bin/env python3
"""Compile the actual clipboard model and window against the products of the documented Debug build."""
import os
import platform
from pathlib import Path
import subprocess
import sys
import plistlib
import shutil

root = Path(__file__).resolve().parents[2]
products = root / "build/DerivedData/Build/Products/Debug"
if not (products / "Search.o").exists():
    sys.exit("Build the Debug app with the README command first.")

sources = [path.stem for path in sorted((root / "App/Sources").glob("*.swift"))
           if path.stem != "KulaHereApp"]
command = ["xcrun", "swiftc", "-parse-as-library", "-swift-version", "6",
           "-target", platform.machine() + "-apple-macos26.0", "-I", str(products)]
command += ["-external-plugin-path", "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins#/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server"]
maps = root / "build/DerivedData/Build/Intermediates.noindex/GeneratedModuleMaps"
for path in sorted(maps.glob("*.modulemap")):
    command += ["-Xcc", "-fmodule-map-file=" + str(path)]
for relative in ["swift-cmark/src/include", "swift-cmark/extensions/include"]:
    command += ["-I", str(root / "build/DerivedData/SourcePackages/checkouts" / relative)]
command += [str(root / "App/Sources" / (name + ".swift")) for name in sources]
command += [str(root / "App/Tests/ClipboardRegression.swift")]
command += [str(path) for path in sorted(products.glob("*.o"))]
binary = root / "build/clipboard-regression"
command += ["-lsqlite3", "-o", str(binary)]
environment = os.environ.copy()
environment.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
subprocess.run(command, env=environment, cwd=root, check=True)
bundle = root / "build/ClipboardRegression.app/Contents"
(bundle / "MacOS").mkdir(parents=True, exist_ok=True)
(bundle / "Resources").mkdir(exist_ok=True)
executable = bundle / "MacOS/ClipboardRegression"
shutil.copy2(binary, executable)
shutil.copy2(products / "KulaHere.app/Contents/Resources/Assets.car", bundle / "Resources/Assets.car")
with (bundle / "Info.plist").open("wb") as output:
    plistlib.dump({"CFBundleExecutable": "ClipboardRegression", "CFBundleIdentifier": "app.kulahere.clipboard-regression",
                  "CFBundleName": "ClipboardRegression", "CFBundlePackageType": "APPL", "LSUIElement": True}, output)
subprocess.run([str(executable), *sys.argv[1:]], env=environment, cwd=root, check=True)
