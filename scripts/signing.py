"""Shared signing for release packaging and local installed bundles."""
from pathlib import Path
import argparse
import subprocess
import tempfile
import plistlib
import re

DEFAULT_IDENTITY = 'Asky Local Signing'
RELEASE_IDENTITY = 'Developer ID Application: Niall Young (V8GVW783CK)'


def is_macho(path):
    # Native executables such as esbuild have no extension; FAT magic can also
    # denote Java bytecode, so confirm candidates with file before signing.
    with path.open('rb') as stream:
        magic = stream.read(4)
    if magic not in (b'\xfe\xed\xfa\xce', b'\xce\xfa\xed\xfe',
                     b'\xfe\xed\xfa\xcf', b'\xcf\xfa\xed\xfe',
                     b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca',
                     b'\xca\xfe\xba\xbf', b'\xbf\xba\xfe\xca'):
        return False
    return 'Mach-O' in subprocess.check_output(['file', '-b', str(path)], text=True)


def check_identity(identity):
    if identity == '-':
        raise SystemExit('Ad-hoc signing is disabled: use a persistent code-signing identity.')
    result = subprocess.check_output(['security', 'find-identity', '-v', '-p', 'codesigning'], text=True)
    for line in result.splitlines():
        match = re.search(r'\b([0-9A-F]{40}) "([^"]+)"', line)
        if match and (identity == match[2] or identity.upper() == match[1]):
            return match[2]
    raise SystemExit(f'Signing identity unavailable: {identity}. Install the certificate and private key '
                     'or supply an existing certificate name/SHA-1 with --signing-identity.')


def sign_bundle(app, identity=DEFAULT_IDENTITY):
    name = check_identity(identity)
    timestamp = '--timestamp' if name.startswith('Developer ID Application:') else '--timestamp=none'
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
        for module in (resources / 'AgentRuntime/node_modules').rglob('*'):
            if not module.is_file() or module.is_symlink():
                continue
            if is_macho(module):
                subprocess.run(['codesign', '--force', '--sign', identity, timestamp,
                                '--options', 'runtime', str(module)], check=True)
        node = resources / 'node/bin/node'
        if node.exists():
            subprocess.run(['codesign', '--force', '--sign', identity, timestamp, '--options', 'runtime',
                            '--entitlements', str(entitlements), str(node)], check=True)
        for name in ('asky-mcp', 'kulahere-mcp'):
            bridge = app / 'Contents/MacOS' / name
            if bridge.exists() and not bridge.is_symlink():
                subprocess.run(['codesign', '--force', '--sign', identity, timestamp,
                                '--options', 'runtime', str(bridge)], check=True)
        subprocess.run(['codesign', '--force', '--sign', identity, timestamp, '--options', 'runtime',
                        '--entitlements', str(repo / 'App/Asky.entitlements'), str(app)], check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app)], check=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Sign an Asky bundle with a persistent identity')
    parser.add_argument('app', type=Path)
    parser.add_argument('--signing-identity', default=DEFAULT_IDENTITY)
    args = parser.parse_args()
    sign_bundle(args.app, args.signing_identity)
