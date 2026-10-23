#!/usr/bin/env python3
"""Compile the actual launcher against the products of the documented Debug build."""
import os
import platform
from pathlib import Path
from regression_resources import copy_core_resources
import subprocess
import sys
import plistlib
import shutil

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
if "--window-search-spaces" not in sys.argv:
    command += [str(root / "App/Sources" / (name + ".swift")) for name in sources]
test_source = ("PluginLauncherRegression.swift" if "--plugins" in sys.argv else
               "ColorPickerRegression.swift" if "--color-picker" in sys.argv else
               "CalculatorHistoryRegression.swift" if "--calculator-history" in sys.argv else
               "LauncherFilterSearchRegression.swift" if "--filter-search" in sys.argv else
               "LauncherFileSearchRegression.swift" if "--file-search" in sys.argv else
               "LauncherFolderRegression.swift" if "--folders" in sys.argv else "LauncherWindowRegression.swift")
if "--window-search" in sys.argv:
    test_source = "WindowSearchRegression.swift"
if "--window-search-live" in sys.argv:
    test_source = "WindowSearchLiveRegression.swift"
if "--window-search-spaces" in sys.argv:
    test_source = "WindowSearchSpacesRegression.swift"
command += [str(root / "App/Tests" / test_source)]
command += [str(path) for path in sorted(products.glob("*.o"))]
artifacts = derived_data / "LauncherRegression" if "ASKY_DERIVED_DATA" in os.environ else root / "build"
artifacts.mkdir(parents=True, exist_ok=True)
binary = artifacts / "launcher-window-regression"
command += ["-lsqlite3", "-o", str(binary)]
environment = os.environ.copy()
environment.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], env=environment, text=True).strip()
command += ["-sdk", sdk]
subprocess.run(command, env=environment, cwd=root, check=True)
bundle = artifacts / "LauncherWindowRegression.app/Contents"
(bundle / "MacOS").mkdir(parents=True, exist_ok=True)
(bundle / "Resources").mkdir(exist_ok=True)
copy_core_resources(products, bundle / "Resources")
executable = bundle / "MacOS/LauncherWindowRegression"
executable.unlink(missing_ok=True)
shutil.copy2(binary, executable)
shutil.copy2(products / "Asky.app/Contents/Resources/Assets.car", bundle / "Resources/Assets.car")
if "--plugins" in sys.argv:
    for language in ("en", "zh-Hans"):
        source = root / "App/Resources" / (language + ".lproj")
        shutil.copytree(source, bundle / "Resources" / source.name, dirs_exist_ok=True)
with (bundle / "Info.plist").open("wb") as output:
    plistlib.dump({"CFBundleExecutable": "LauncherWindowRegression", "CFBundleIdentifier": "app.asky.plugin-launcher-regression" if "--plugins" in sys.argv else "app.asky.launcher-window-regression",
                  "CFBundleName": "LauncherWindowRegression", "CFBundlePackageType": "APPL", "LSUIElement": True, "KHSourceRoot": str(root)}, output)
subprocess.run([str(executable), *sys.argv[1:]], env=environment, cwd=root, check=True)
