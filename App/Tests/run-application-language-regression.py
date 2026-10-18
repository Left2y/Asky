#!/usr/bin/env python3
"""Verify native app localization and settings using an isolated regression bundle."""
import os
import platform
from pathlib import Path
from regression_resources import copy_core_resources
import subprocess
import sys
import plistlib
import shutil

root = Path(__file__).resolve().parents[2]
subprocess.run([sys.executable, str(root / "App/Tests/check-localization.py")], check=True)
derived_data = Path(os.environ.get("ASKY_DERIVED_DATA", os.environ.get("KULAHERE_DERIVED_DATA", root / "build/DerivedData")))
products = derived_data / "Build/Products/Debug"
if not (products / "Search.o").exists():
    sys.exit("Build the Debug app with the README command first.")

environment = os.environ.copy()
environment.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], env=environment, text=True).strip()

sources = [path.stem for path in sorted((root / "App/Sources").glob("*.swift"))
           if path.stem != "AskyApp"]
command = ["xcrun", "swiftc", "-parse-as-library", "-swift-version", "6",
           "-sdk", sdk, "-target", platform.machine() + "-apple-macos26.0", "-I", str(products)]
command += ["-external-plugin-path", "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins#/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server"]
maps = derived_data / "Build/Intermediates.noindex/GeneratedModuleMaps"
for path in sorted(maps.glob("*.modulemap")):
    command += ["-Xcc", "-fmodule-map-file=" + str(path)]
for relative in ["swift-cmark/src/include", "swift-cmark/extensions/include"]:
    command += ["-I", str(derived_data / "SourcePackages/checkouts" / relative)]
command += [str(root / "App/Sources" / (name + ".swift")) for name in sources]
command += [str(root / "App/Tests/ApplicationLanguageRegression.swift")]
command += [str(path) for path in sorted(products.glob("*.o"))]
binary = root / "build/application-language-regression"
command += ["-lsqlite3", "-o", str(binary)]
subprocess.run(command, env=environment, cwd=root, check=True)
bundle = root / "build/ApplicationLanguageRegression.app/Contents"
(bundle / "MacOS").mkdir(parents=True, exist_ok=True)
(bundle / "Resources").mkdir(exist_ok=True)
copy_core_resources(products, bundle / "Resources")
executable = bundle / "MacOS/ApplicationLanguageRegression"
shutil.copy2(binary, executable)
shutil.copy2(products / "Asky.app/Contents/Resources/Assets.car", bundle / "Resources/Assets.car")
for localization in (products / "Asky.app/Contents/Resources").glob("*.lproj"):
    shutil.copytree(localization, bundle / "Resources" / localization.name, dirs_exist_ok=True)
with (bundle / "Info.plist").open("wb") as output:
    plistlib.dump({"CFBundleExecutable": "ApplicationLanguageRegression", "CFBundleIdentifier": "app.asky.application-language-regression",
                  "CFBundleDevelopmentRegion": "zh-Hans", "CFBundleName": "ApplicationLanguageRegression", "CFBundlePackageType": "APPL", "LSUIElement": True}, output)
subprocess.run([str(executable), *sys.argv[1:]], env=environment, cwd=root, check=True)
