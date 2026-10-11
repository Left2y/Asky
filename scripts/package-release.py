from pathlib import Path
import hashlib, json, plistlib, shutil, subprocess, tempfile

import argparse
parser = argparse.ArgumentParser(description="Package a built Asky release as DMG and updater ZIP")
parser.add_argument('--version', required=True)
parser.add_argument('--build', required=True)
parser.add_argument('--derived-data', required=True, type=Path)
parser.add_argument('--runtime', required=True, type=Path)
parser.add_argument('--node-root', required=True, type=Path)
args = parser.parse_args()
repo = Path(__file__).resolve().parent.parent
root = repo / 'build'
commit = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip()
if subprocess.check_output(['git', '-C', str(repo), 'status', '--porcelain'], text=True).strip():
    raise SystemExit('Commit source changes before packaging a release')
app = root / f'release-staging-{args.version}/Asky.app'
app.parent.mkdir(parents=True, exist_ok=True)
if app.exists():
    raise SystemExit(f'Staging bundle already exists: {app}')
shutil.copytree(args.derived_data / 'Build/Products/Release/Asky.app', app)
resources = app / 'Contents/Resources'
shutil.copy2(repo / 'LICENSE', resources / 'LICENSE')
shutil.copytree(args.runtime, resources / 'AgentRuntime')
node_dir = resources / 'node'
(node_dir / 'bin').mkdir(parents=True)
shutil.copy2(args.node_root / 'bin/node', node_dir / 'bin/node')
shutil.copy2(args.node_root / 'LICENSE', node_dir / 'LICENSE')
info_path = app / 'Contents/Info.plist'
with info_path.open('rb') as f:
    info = plistlib.load(f)
info['CFBundleShortVersionString'] = args.version
info['CFBundleVersion'] = args.build
info['KHReleaseCommit'] = commit
info.pop('KHSourceRoot', None)
with info_path.open('wb') as f:
    plistlib.dump(info, f)
entitlements = root / 'node-release.entitlements'
with entitlements.open('wb') as f:
    plistlib.dump({
        'com.apple.security.cs.allow-jit': True,
        'com.apple.security.cs.allow-unsigned-executable-memory': True,
        'com.apple.security.cs.disable-library-validation': True,
    }, f)
for module in (resources / 'AgentRuntime/node_modules').rglob('*.node'):
    kind = subprocess.check_output(['file', '-b', str(module)], text=True)
    if 'Mach-O' in kind:
        subprocess.run(['codesign', '--force', '--sign', '-', str(module)], check=True)
subprocess.run(['codesign', '--force', '--sign', '-', '--options', 'runtime', '--entitlements', str(entitlements), str(node_dir / 'bin/node')], check=True)
subprocess.run(['codesign', '--force', '--sign', '-', '--options', 'runtime', '--entitlements', str(repo / 'App/Asky.entitlements'), str(app)], check=True)
subprocess.run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app)], check=True)
with tempfile.TemporaryDirectory(prefix='kulahere-release-smoke-') as data_dir:
    result = subprocess.run([str(node_dir / 'bin/node'), str(resources / 'AgentRuntime/dist/src/main.js'), '--data-dir', data_dir], input='{"type":"hello","protocol":1}\n{"type":"shutdown"}\n', text=True, capture_output=True, timeout=30, env={'HOME': data_dir, 'PATH': '/usr/bin:/bin', 'TMPDIR': data_dir})
    (root / f'release-{args.version}-bundled-runtime-smoke.log').write_text(result.stdout + result.stderr)
    assert result.returncode == 0, result.stderr
    frames = [json.loads(line) for line in result.stdout.splitlines()]
    assert any(frame.get('type') == 'ready' and frame.get('protocol') == 1 for frame in frames), result.stdout
release_dir = root / f'releases/{args.version}'
release_dir.mkdir(parents=True, exist_ok=True)
zip_path = release_dir / f'Asky-{args.version}-macos-arm64.zip'
subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(app), str(zip_path)], check=True)
sha = hashlib.sha256(zip_path.read_bytes()).hexdigest()
(release_dir / (zip_path.name + '.sha256')).write_text(f'{sha}  {zip_path.name}\n')
print(json.dumps({'artifact': str(zip_path), 'sha256': sha, 'size': zip_path.stat().st_size}))

# A standard drag-install image: the app and a shortcut to Applications.
with tempfile.TemporaryDirectory(prefix='asky-dmg-') as temp:
    folder = Path(temp)
    shutil.copytree(app, folder / 'Asky.app', symlinks=True)
    (folder / 'Applications').symlink_to('/Applications')
    dmg = release_dir / f'Asky-{args.version}-macos-arm64.dmg'
    subprocess.run(['hdiutil', 'create', '-volname', f'Asky {args.version}', '-srcfolder', str(folder),
                    '-format', 'UDZO', str(dmg)], check=True)
    checksum = hashlib.sha256(dmg.read_bytes()).hexdigest()
    (release_dir / (dmg.name + '.sha256')).write_text(f'{checksum}  {dmg.name}\n')
    subprocess.run(['hdiutil', 'verify', str(dmg)], check=True)
    print(json.dumps({'artifact': str(dmg), 'sha256': checksum, 'size': dmg.stat().st_size}))
