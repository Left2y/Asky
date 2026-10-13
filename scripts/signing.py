"""Shared signing for release packaging and local installed bundles."""
from pathlib import Path
import argparse
import subprocess
import tempfile
import plistlib

DEFAULT_IDENTITY = 'Asky Local Signing'


def check_identity(identity):
    if identity == '-':
        raise SystemExit('Ad-hoc signing is disabled: use a persistent code-signing identity.')
    result = subprocess.check_output(['security', 'find-identity', '-v', '-p', 'codesigning'], text=True)
    if not any(f'"{identity}"' in line or identity.upper() in line.split()[1:2]
               for line in result.splitlines()):
        raise SystemExit(f'Signing identity unavailable: {identity}. Run python3 scripts/setup-local-signing.py '
                         'or supply an existing certificate name/SHA-1 with --signing-identity.')


def sign_bundle(app, identity=DEFAULT_IDENTITY):
    check_identity(identity)
    repo = Path(__file__).resolve().parent.parent
    resources = app / 'Contents/Resources'
    with tempfile.TemporaryDirectory(prefix='asky-entitlements-') as temporary:
        entitlements = Path(temporary) / 'node.plist'
        with entitlements.open('wb') as stream:
            plistlib.dump({
                'com.apple.security.cs.allow-jit': True,
                'com.apple.security.cs.allow-unsigned-executable-memory': True,
                'com.apple.security.cs.disable-library-validation': True,
            }, stream)
        for module in (resources / 'AgentRuntime/node_modules').rglob('*.node'):
            if 'Mach-O' in subprocess.check_output(['file', '-b', str(module)], text=True):
                subprocess.run(['codesign', '--force', '--sign', identity, '--timestamp=none', str(module)], check=True)
        node = resources / 'node/bin/node'
        if node.exists():
            subprocess.run(['codesign', '--force', '--sign', identity, '--timestamp=none', '--options', 'runtime',
                            '--entitlements', str(entitlements), str(node)], check=True)
        bridge = app / 'Contents/MacOS/asky-mcp'
        if bridge.exists():
            subprocess.run(['codesign', '--force', '--sign', identity, '--timestamp=none',
                            '--options', 'runtime', str(bridge)], check=True)
        subprocess.run(['codesign', '--force', '--sign', identity, '--timestamp=none', '--options', 'runtime',
                        '--entitlements', str(repo / 'App/Asky.entitlements'), str(app)], check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app)], check=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Sign an Asky bundle with a persistent identity')
    parser.add_argument('app', type=Path)
    parser.add_argument('--signing-identity', default=DEFAULT_IDENTITY)
    args = parser.parse_args()
    sign_bundle(args.app, args.signing_identity)
