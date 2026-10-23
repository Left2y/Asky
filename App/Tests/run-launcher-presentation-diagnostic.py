#!/usr/bin/env python3
"""Record independent Debug renderer cold starts without touching the installed app/data."""
import argparse
import json
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--app', type=Path, default=root / 'build/DerivedData/Build/Products/Debug/Asky.app')
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--runs', type=int, default=20, help='independent processes per appearance')
args = parser.parse_args()
if args.runs < 1:
    parser.error('--runs must be positive')
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
app = args.app.resolve()
executable = app / 'Contents/MacOS/Asky'
if not executable.is_file() or b'--diagnose-launcher requires an absolute --diagnostic-root' not in executable.read_bytes():
    parser.error('--app must be a Debug build with the isolated launcher diagnostic entry')
recorder = output / 'presentation-recorder'
env = os.environ.copy()
env.setdefault('DEVELOPER_DIR', '/Applications/Xcode.app/Contents/Developer')
subprocess.run(['xcrun', 'swiftc', '-parse-as-library', '-swift-version', '6',
                str(root / 'App/Tests/LauncherPresentationRecorder.swift'), '-o', str(recorder)],
               env=env, check=True)
# Local path replacement exercises a new bundle path, not the signed production updater.
replacement = output / 'Replaced/Asky.app'
replacement.parent.mkdir(exist_ok=True)
if replacement.exists():
    shutil.rmtree(replacement)
shutil.copytree(app, replacement, symlinks=True)
report = {'app': str(app), 'requestedFPS': 60, 'runs': [],
          'coverage': 'isolated Debug renderer; new processes and copied bundle; not installed-update integration'}
for appearance in ('light', 'dark'):
    video = output / (appearance + '.mp4')
    video.unlink(missing_ok=True)
    capture = subprocess.Popen([str(recorder), str(video)], stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        selector = selectors.DefaultSelector()
        selector.register(capture.stdout, selectors.EVENT_READ)
        if not selector.select(timeout=20):
            raise RuntimeError('screen recorder did not become ready; inspect Screen Recording access')
        ready = capture.stdout.readline().strip().split()
        if len(ready) != 2 or ready[0] != 'READY':
            raise RuntimeError('screen recorder returned an invalid ready message')
        display_id = ready[1]
        selector.close()
        print(f'{appearance}: recorder ready', flush=True)
        for index in range(args.runs):
            bundle = app if index < (args.runs + 1) // 2 else replacement
            executable = bundle / 'Contents/MacOS/Asky'
            with tempfile.TemporaryDirectory(prefix='asky-presentation-') as data:
                command = [str(executable), '--diagnose-launcher', '--diagnostic-root', data, '--diagnostic-screen', display_id]
                if appearance == 'dark':
                    command.append('--diagnostic-dark')
                log = output / f'{appearance}-{index:02d}.log'
                start = time.monotonic()
                with log.open('w') as stream:
                    subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT,
                                   env=env, timeout=20, check=True)
                trace = log.read_text()
                if 'event=ordered-front' not in trace:
                    raise RuntimeError(f'Debug diagnostic did not show a launcher: {log}')
                report['runs'].append({'appearance': appearance, 'index': index,
                                       'copiedBundle': bundle == replacement,
                                       'elapsedSeconds': time.monotonic() - start,
                                       'log': log.name})
                print(f'{appearance}: {index + 1}/{args.runs}', flush=True)
    finally:
        capture.stdin.close()
        capture.wait(timeout=20)
        recorder_log = capture.stdout.read() + capture.stderr.read()
        (output / f'{appearance}-recording.log').write_text(recorder_log)
        if capture.returncode != 0:
            raise RuntimeError(f'recorder failed: {recorder_log}')
    if not video.exists() or video.stat().st_size < 1000:
        raise RuntimeError(f'missing recording: {video}')
(output / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(f'Completed {len(report["runs"])} independent processes. Evidence: {output}', flush=True)
