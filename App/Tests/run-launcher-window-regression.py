#!/usr/bin/env python3
"""Compile the actual launcher against the products of the documented Debug build."""
import os
import platform
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
products = root / "build/DerivedData/Build/Products/Debug"
if not (products / "Search.o").exists():
    sys.exit("Build the Debug app with the README command first.")

sources = ["AppModel", "ClipboardMonitor", "ConfirmationCenter", "LauncherModel",
           "LauncherSearchField", "LauncherView"]
command = ["xcrun", "swiftc", "-parse-as-library", "-swift-version", "6",
           "-target", platform.machine() + "-apple-macos26.0", "-I", str(products)]
maps = root / "build/DerivedData/Build/Intermediates.noindex/GeneratedModuleMaps"
for path in sorted(maps.glob("*.modulemap")):
    command += ["-Xcc", "-fmodule-map-file=" + str(path)]
for relative in ["swift-cmark/src/include", "swift-cmark/extensions/include"]:
    command += ["-I", str(root / "build/DerivedData/SourcePackages/checkouts" / relative)]
command += [str(root / "App/Sources" / (name + ".swift")) for name in sources]
command += [str(root / "App/Tests/LauncherWindowRegression.swift")]
command += [str(path) for path in sorted(products.glob("*.o"))]
binary = root / "build/launcher-window-regression"
command += ["-lsqlite3", "-o", str(binary)]
environment = os.environ.copy()
environment.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
subprocess.run(command, env=environment, cwd=root, check=True)
subprocess.run([str(binary)], env=environment, cwd=root, check=True)
