"""Notarize Developer ID artifacts using credentials stored in Keychain."""
import json
import subprocess

DEFAULT_PROFILE = 'Asky'


def check_profile(profile):
    subprocess.run(['xcrun', 'notarytool', 'history', '--keychain-profile', profile,
                    '--output-format', 'json'], check=True, stdout=subprocess.DEVNULL)


def notarize(archive, profile, log_path):
    result = subprocess.run(['xcrun', 'notarytool', 'submit', str(archive),
                             '--keychain-profile', profile,
                             '--output-format', 'json'], text=True, capture_output=True)
    log_path.write_text(result.stdout)
    if result.stderr:
        log_path.with_suffix('.stderr.log').write_text(result.stderr)
    if result.returncode:
        raise SystemExit(f'Notarization command failed; see {log_path}')
    submission = json.loads(result.stdout)
    print(f'Notarization submitted: {submission["id"]}; receipt: {log_path}', flush=True)
    result = subprocess.run(['xcrun', 'notarytool', 'wait', submission['id'],
                             '--keychain-profile', profile, '--output-format', 'json'],
                            text=True, capture_output=True)
    status_path = log_path.with_suffix('.status.json')
    status_path.write_text(result.stdout)
    if result.stderr:
        status_path.with_suffix('.stderr.log').write_text(result.stderr)
    if result.returncode:
        raise SystemExit(f'Notarization wait failed; submission ID is saved in {log_path}')
    status = json.loads(result.stdout)
    detail_path = log_path.with_suffix('.details.json')
    subprocess.run(['xcrun', 'notarytool', 'log', submission['id'],
                    '--keychain-profile', profile, str(detail_path)], check=True)
    if status.get('status') != 'Accepted':
        raise SystemExit(f'Notarization was not accepted; see {detail_path}')
    print(f'Notarization accepted: {submission["id"]}', flush=True)


def staple(artifact):
    subprocess.run(['xcrun', 'stapler', 'staple', str(artifact)], check=True)
    subprocess.run(['xcrun', 'stapler', 'validate', str(artifact)], check=True)
