"""Create a persistent, anonymous code-signing identity in the login keychain."""
from pathlib import Path
import subprocess
import tempfile
import secrets
import os

NAME = 'Asky Local Signing'
keychain = Path.home() / 'Library/Keychains/login.keychain-db'
existing = subprocess.run(['security', 'find-certificate', '-c', NAME, str(keychain)],
                          capture_output=True)
if existing.returncode == 0:
    print(f'{NAME} already exists; preserving the existing certificate and private key.')
else:
    with tempfile.TemporaryDirectory(prefix='asky-signing-') as directory:
        root = Path(directory)
        config = root / 'certificate.cnf'
        config.write_text('''[req]
distinguished_name = subject
x509_extensions = extensions
prompt = no
[subject]
CN = Asky Local Signing
[extensions]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = codeSigning
''')
        subprocess.run(['/usr/bin/openssl', 'req', '-new', '-x509', '-newkey', 'rsa:3072',
                        '-nodes', '-days', '3650', '-config', str(config),
                        '-keyout', str(root / 'key.pem'), '-out', str(root / 'cert.pem')],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        password = secrets.token_hex(24)
        environment = dict(os.environ, ASKY_P12_PASSWORD=password)
        subprocess.run(['/usr/bin/openssl', 'pkcs12', '-export', '-inkey', str(root / 'key.pem'),
                        '-in', str(root / 'cert.pem'), '-out', str(root / 'identity.p12'),
                        '-name', NAME, '-keypbe', 'PBE-SHA1-3DES', '-certpbe', 'PBE-SHA1-3DES',
                        '-macalg', 'sha1', '-passout', 'env:ASKY_P12_PASSWORD'], check=True, env=environment)
        result = subprocess.run(['security', 'import', str(root / 'identity.p12'), '-k', str(keychain),
                        '-P', password, '-T', '/usr/bin/codesign'], check=False, capture_output=True)
        if result.returncode:
            raise SystemExit('Keychain import failed: ' + result.stderr.decode().strip())
identities = subprocess.check_output(['security', 'find-identity', '-v', '-p', 'codesigning',
                                      str(keychain)], text=True)
if f'"{NAME}"' not in identities:
    with tempfile.TemporaryDirectory(prefix='asky-signing-trust-') as directory:
        certificate = Path(directory) / 'cert.pem'
        certificate.write_bytes(subprocess.check_output(['security', 'find-certificate', '-c', NAME,
                                                         '-p', str(keychain)]))
        subprocess.run(['security', 'add-trusted-cert', '-r', 'trustRoot', '-p', 'codeSign',
                        '-k', str(keychain), str(certificate)], check=True)
    identities = subprocess.check_output(['security', 'find-identity', '-v', '-p', 'codesigning',
                                          str(keychain)], text=True)
if f'"{NAME}"' not in identities:
    raise SystemExit('Certificate exists but is not a valid signing identity. Check its private key '
                     'and Code Signing trust in Keychain Access; do not recreate it.')
print(identities.strip())
print('Keep this identity in the keychain for future builds. Private temporary files were removed.')
