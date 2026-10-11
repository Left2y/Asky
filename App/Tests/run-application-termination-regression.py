#!/usr/bin/env python3
"""Exercise AppKit quit from a Swift task and the actual updater swap/relaunch script."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BINARY = ROOT / "build/application-termination-regression"
ENV = {**os.environ, "DEVELOPER_DIR": "/Applications/Xcode.app/Contents/Developer"}
BINARY.parent.mkdir(exist_ok=True)
subprocess.run([
    "xcrun", "swiftc", "-parse-as-library", "-swift-version", "6",
    "App/Sources/ApplicationTermination.swift", "App/Tests/ApplicationTerminationRegression.swift",
    "-o", str(BINARY),
], cwd=ROOT, env=ENV, check=True)

# Keep a negative control: the original terminateLater implementation must reproduce the hang.
legacy = subprocess.Popen([str(BINARY), "--legacy"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
try:
    legacy.communicate(timeout=3)
    raise AssertionError("Original termination path did not reproduce the hang")
except subprocess.TimeoutExpired:
    legacy.kill()
    legacy.communicate()
print("Original terminateLater hang reproduced")

result = subprocess.run([str(BINARY)], capture_output=True, text=True, timeout=5, check=True)
assert "native regression passed" in result.stdout, result
print(result.stdout.strip())

source = (ROOT / "Packages/KulaCore/Sources/ToolService/AppUpdate.swift").read_text()
script = source.split('static let swapScript = """', 1)[1].split('"""', 1)[0]
with tempfile.TemporaryDirectory(prefix="asky-update-regression-") as directory:
    root = Path(directory)
    installed = root / "Applications/Asky.app"
    staged = root / "work/extracted/Asky.app"
    installed.mkdir(parents=True)
    staged.mkdir(parents=True)
    (installed / "version").write_text("old")
    (staged / "version").write_text("new")
    fake_bin = root / "bin"
    fake_bin.mkdir()
    # Replace LaunchServices only: actually launch a fresh native process after the swap.
    opener = fake_bin / "open"
    opener.write_text('#!/bin/sh\nexec "$ASKY_TEST_BINARY" > "$ASKY_TEST_RELAUNCH_LOG" 2>&1\n')
    opener.chmod(0o755)
    log = root / "relaunch.log"
    old = subprocess.Popen([str(BINARY)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    helper = subprocess.Popen(["/bin/sh", "-c", script, "asky-update", str(old.pid),
                               str(installed), str(staged), str(root / "work")], env={
        **ENV, "PATH": f"{fake_bin}:/usr/bin:/bin", "ASKY_TEST_BINARY": str(BINARY),
        "ASKY_TEST_RELAUNCH_LOG": str(log),
    }, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        output, error = old.communicate(timeout=5)
        assert old.returncode == 0 and b"native regression passed" in output, (output, error)
        output, error = helper.communicate(timeout=5)
        assert helper.returncode == 0, (output, error)
        assert (installed / "version").read_text() == "new"
        assert not (root / "work").exists()
        assert "native regression passed" in log.read_text()
    finally:
        for process in (old, helper):
            if process.poll() is None:
                process.kill()
                process.communicate()
print("Updater waited for exit, swapped bundles, cleaned staging and relaunched a native process")
