#!/usr/bin/env python3
"""Compile the actual launcher against the products of the documented Debug build."""
import os
import platform
from pathlib import Path
from regression_resources import copy_core_resources
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
products = root / "build/DerivedData/Build/Products/Debug"
if not (products / "Search.o").exists():
    sys.exit("Build the Debug app with the README command first.")

sources = [path.stem for path in sorted((root / "App/Sources").glob("*.swift"))
           if path.stem not in {"AskyApp", "KulaHereApp"}]
command = ["xcrun", "swiftc", "-parse-as-library", "-swift-version", "6",
           "-target", platform.machine() + "-apple-macos26.0", "-I", str(products)]
maps = root / "build/DerivedData/Build/Intermediates.noindex/GeneratedModuleMaps"
for path in sorted(maps.glob("*.modulemap")):
    command += ["-Xcc", "-fmodule-map-file=" + str(path)]
for relative in ["swift-cmark/src/include", "swift-cmark/extensions/include"]:
    command += ["-I", str(root / "build/DerivedData/SourcePackages/checkouts" / relative)]
command += [str(root / "App/Sources" / (name + ".swift")) for name in sources]
command += [str(root / "App/Tests/LauncherCalculationRegression.swift")]
command += [str(path) for path in sorted(products.glob("*.o"))]
binary = root / "build/launcher-calculation-regression"
command += ["-lsqlite3", "-o", str(binary)]
copy_core_resources(products, binary.parent)
environment = os.environ.copy()
environment.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], env=environment, text=True).strip()
command += ["-sdk", sdk]
subprocess.run(command, env=environment, cwd=root, check=True)
subprocess.run([str(binary), *sys.argv[1:]], env=environment, cwd=root, check=True)
