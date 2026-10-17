#!/usr/bin/env python3
"""Compile the actual launcher against the products of the documented Debug build."""
import os
import platform
from pathlib import Path
import subprocess
import sys
import plistlib
import shutil
import tempfile

root = Path(__file__).resolve().parents[2]
derived_data = Path(os.environ.get("ASKY_DERIVED_DATA", str(root / "build/DerivedData")))
products = derived_data / "Build/Products/Debug"
if not (products / "Search.o").exists():
    sys.exit("Build the Debug app with the README command first.")

sources = [path.stem for path in sorted((root / "App/Sources").glob("*.swift"))
           if path.stem != "AskyApp"]
command = ["xcrun", "swiftc", "-parse-as-library", "-swift-version", "6",
           "-target", platform.machine() + "-apple-macos26.0", "-I", str(products)]
maps = derived_data / "Build/Intermediates.noindex/GeneratedModuleMaps"
for path in sorted(maps.glob("*.modulemap")):
    command += ["-Xcc", "-fmodule-map-file=" + str(path)]
for relative in ["swift-cmark/src/include", "swift-cmark/extensions/include"]:
    command += ["-I", str(derived_data / "SourcePackages/checkouts" / relative)]
# Freeze inputs so concurrent edits in the shared checkout cannot interrupt swiftc.
snapshot = tempfile.TemporaryDirectory(prefix="asky-quit-sources-")
snapshot_root = Path(snapshot.name)
for name in sources:
    shutil.copy2(root / "App/Sources" / (name + ".swift"), snapshot_root / (name + ".swift"))
shutil.copy2(root / "App/Tests/QuitAskyRegression.swift", snapshot_root / "QuitAskyRegression.swift")
command += [str(snapshot_root / (name + ".swift")) for name in sources]
command += [str(snapshot_root / "QuitAskyRegression.swift")]
command += [str(path) for path in sorted(products.glob("*.o"))]
artifacts = derived_data / "LauncherRegression" if "ASKY_DERIVED_DATA" in os.environ else root / "build"
artifacts.mkdir(parents=True, exist_ok=True)
binary = artifacts / "quit-asky-regression"
command += ["-lsqlite3", "-o", str(binary)]
environment = os.environ.copy()
environment.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], env=environment, text=True).strip()
command += ["-sdk", sdk]
subprocess.run(command, env=environment, cwd=root, check=True)
bundle = artifacts / "QuitAskyRegression.app/Contents"
(bundle / "MacOS").mkdir(parents=True, exist_ok=True)
(bundle / "Resources").mkdir(exist_ok=True)
executable = bundle / "MacOS/QuitAskyRegression"
executable.unlink(missing_ok=True)
shutil.copy2(binary, executable)
shutil.copy2(products / "Asky.app/Contents/Resources/Assets.car", bundle / "Resources/Assets.car")
with (bundle / "Info.plist").open("wb") as output:
    plistlib.dump({"CFBundleExecutable": "QuitAskyRegression", "CFBundleIdentifier": "app.asky.quit-asky-regression",
                  "CFBundleName": "QuitAskyRegression", "CFBundlePackageType": "APPL", "LSUIElement": True}, output)
subprocess.run([str(executable), *sys.argv[1:]], env=environment, cwd=root, check=True)
