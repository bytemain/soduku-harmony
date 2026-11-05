#!/usr/bin/env python3
"""Sign an existing release APP using the official SDK; never issue credentials."""
import argparse
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
BUNDLE = 'io.oranix.soduku.mini'
DEVECO = Path('/Applications/DevEco-Studio.app/Contents')
LOG = []
SECRETS = []
LOG_PATH = None


def redact(value):
    for secret in sorted(SECRETS, key=len, reverse=True):
        if secret:
            value = value.replace(secret, '[REDACTED]')
            value = value.replace(secret.replace('\\', '\\\\').replace('"', '\\"'), '[REDACTED]')
    return value


def run(label, command, payload=None):
    # No shell, inherited terminal output, or command-line password arguments.
    result = subprocess.run(command, input=payload, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, check=False)
    LOG.append(label + ': exit ' + str(result.returncode))
    if result.stderr:
        LOG.append(redact(result.stderr.decode('utf-8', errors='replace')))
    if result.returncode:
        LOG.append(redact(result.stdout.decode('utf-8', errors='replace')))
        raise RuntimeError(label + ' failed; see the redacted signing log.')
    return result.stdout


def require_file(path, label, private=False):
    if path.is_symlink() or not path.is_file() or path.stat().st_size == 0:
        raise RuntimeError('Missing or invalid ' + label + '.')
    if private and os.name == 'posix':
        info = path.stat()
        if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077:
            raise RuntimeError(label + ' must be owned by this user and inaccessible to group/others (chmod 600).')


def read_password(path, env_name):
    value = os.environ.get(env_name)
    if value is None:
        require_file(path, env_name + ' file', private=True)
        value = path.read_text(encoding='utf-8').removesuffix('\n').removesuffix('\r')
    if not value or any(char in value for char in ['\n', '\r', '\x00']):
        raise RuntimeError(env_name + ' must be a nonempty single-line value.')
    SECRETS.append(value)
    return value


def spki(data, csr=False):
    kind = 'req' if csr else 'x509'
    # Public certificates/CSRs can be PEM or DER; no private key is passed here.
    form = 'PEM' if b'-----BEGIN' in data else 'DER'
    public = run('Read public key', ['/usr/bin/openssl', kind, '-inform', form,
                 '-pubkey', '-noout'], data)
    return hashlib.sha256(run('Normalize public key', ['/usr/bin/openssl', 'pkey',
                           '-pubin', '-outform', 'DER'], public)).hexdigest()


def certificate_fingerprint(data):
    form = 'PEM' if b'-----BEGIN' in data else 'DER'
    der = run('Normalize leaf certificate', ['/usr/bin/openssl', 'x509', '-inform', form,
              '-outform', 'DER'], data)
    return hashlib.sha256(der).hexdigest()


def certificate_blocks(data):
    # AGC certificate chains can be root-first; PEM ordering is not leaf identity.
    if b'-----BEGIN CERTIFICATE-----' in data:
        blocks = re.findall(rb'-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----',
                            data.replace(b'\\n', b'\n'), flags=re.DOTALL)
        if not blocks:
            raise RuntimeError('Certificate chain contains no certificate blocks.')
        return blocks
    compact = re.sub(rb'\s+', b'', data)
    try:
        # Profile distribution-certificate may contain base64 DER without PEM headers.
        decoded = base64.b64decode(compact, validate=True)
        if decoded.startswith(b'\x30'):
            return [decoded]
    except ValueError:
        pass
    return [data]


def select_certificate(data, expected_spki):
    matching = [item for item in certificate_blocks(data) if spki(item) == expected_spki]
    if len(matching) != 1:
        raise RuntimeError('Certificate chain must contain exactly one certificate matching the CSR public key.')
    return matching[0]


def find_profile(value):
    """Accept the SDK's JSON profile or a JSON wrapper; fail if ambiguous."""
    found = []
    def visit(item):
        if isinstance(item, dict):
            # The bundled SDK VerificationResult model exposes this explicit flag.
            # A failed verification must not become a pass merely because content exists.
            if 'verifiedPassed' in item and item['verifiedPassed'] is not True:
                raise RuntimeError('The SDK explicitly reported failed Profile verification.')
            if isinstance(item.get('bundle-info'), dict) and 'type' in item:
                found.append(item)
            else:
                for child in item.values():
                    visit(child)
        elif isinstance(item, list):
            for child in item:
                visit(child)
        elif isinstance(item, str) and item.lstrip().startswith('{'):
            try:
                visit(json.loads(item))
            except ValueError:
                pass
    visit(value)
    unique = {json.dumps(item, sort_keys=True): item for item in found}
    if len(unique) != 1:
        raise RuntimeError('The SDK profile output did not contain exactly one recognizable profile.')
    return next(iter(unique.values()))


def java_arg(value):
    value = str(value)
    if any(char in value for char in ['\n', '\r', '\x00']):
        raise RuntimeError('Java argument contains unsupported control characters.')
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'


def main():
    global LOG_PATH
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, default=ROOT / 'release-artifacts/good-sudoku-1.0.0-unsigned.app')
    parser.add_argument('--output', type=Path, default=ROOT / 'release-artifacts/good-sudoku-1.0.0-signed.app')
    parser.add_argument('--materials-dir', type=Path, default=Path.home() / '.ohos/release' / BUNDLE)
    parser.add_argument('--key-alias', default=os.environ.get('SIGNING_KEY_ALIAS', 'sudoku_release'))
    parser.add_argument('--password-file', type=Path)
    parser.add_argument('--key-password-file', type=Path)
    parser.add_argument('--deveco', type=Path, default=DEVECO)
    parser.add_argument('--check', action='store_true', help='Validate public materials only; do not read passwords or sign.')
    args = parser.parse_args()
    materials = args.materials_dir.expanduser().resolve()
    paths = {name: materials / ('sudoku-release.' + extension) for name, extension in
             [('key', 'p12'), ('csr', 'csr'), ('cert', 'cer'), ('profile', 'p7b')]}
    java = args.deveco / 'jbr/Contents/Home/bin/java'
    jar = args.deveco / 'sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar'
    require_file(java, 'official Java runtime')
    require_file(jar, 'official hap-sign-tool.jar')
    for name, path in paths.items():
        require_file(path, name, private=name == 'key')
    if os.name == 'posix' and (materials.stat().st_uid != os.getuid() or stat.S_IMODE(materials.stat().st_mode) & 0o077):
        raise RuntimeError('The materials directory must be private to this user (chmod 700).')
    LOG_PATH = materials / 'signing-last-run.log'
    if LOG_PATH.is_symlink():
        raise RuntimeError('Signing log path must not be a symlink.')
    require_file(args.input, 'unsigned APP')
    if args.input.resolve() == args.output.resolve():
        raise RuntimeError('Input and output APP paths must differ.')
    if not args.key_alias or any(c in args.key_alias for c in '\r\n\x00'):
        raise RuntimeError('A valid key alias is required.')
    store_password_file = args.password_file or materials / 'keystore-password.txt'
    key_password_file = args.key_password_file or store_password_file
    for name, path in [('RELEASE_KEYSTORE_PASSWORD', store_password_file), ('RELEASE_KEY_PASSWORD', key_password_file)]:
        if name not in os.environ:
            require_file(path, name + ' file', private=True)
    with zipfile.ZipFile(args.input) as app:
        if app.testzip() is not None:
            raise RuntimeError('Unsigned APP ZIP integrity check failed.')
        hap_names = [name for name in app.namelist() if name.endswith('.hap')]
        if hap_names != ['entry-default.hap']:
            raise RuntimeError('This signing entry supports the current single-entry APP only.')
        inner_hap = app.read(hap_names[0])
        with zipfile.ZipFile(io.BytesIO(inner_hap)) as hap:
            metadata = json.loads(hap.read('module.json'))
            if metadata['app'].get('bundleName') != BUNDLE or metadata['app'].get('debug') is not False or metadata['app'].get('buildMode') != 'release':
                raise RuntimeError('Input must be the intended non-debug release APP.')
    key_hash = spki(paths['csr'].read_bytes(), csr=True)
    cert_data = select_certificate(paths['cert'].read_bytes(), key_hash)
    cert_hash = certificate_fingerprint(cert_data)
    run('Verify CSR signature', ['/usr/bin/openssl', 'req', '-in', str(paths['csr']), '-verify', '-noout'])
    run('Check certificate expiry', ['/usr/bin/openssl', 'x509', '-inform', 'PEM' if b'-----BEGIN' in cert_data else 'DER', '-checkend', '0', '-noout'], cert_data)
    with tempfile.TemporaryDirectory(prefix='signing-run-', dir=materials) as temporary:
        scratch = Path(temporary)
        def sdk(label, options):
            output = run(label, [str(java), '-jar', str(jar)] + list(map(str, options)))
            LOG.append(redact(output.decode('utf-8', errors='replace')))
            return output
        profile_result = scratch / 'profile-result.json'
        sdk('Verify release profile', ['verify-profile', '-inFile', paths['profile'], '-outFile', profile_result])
        require_file(profile_result, 'verified profile output')
        profile = find_profile(json.loads(profile_result.read_text()))
        bundle_info = profile['bundle-info']
        if profile['type'] != 'release' or bundle_info.get('bundle-name') != BUNDLE:
            raise RuntimeError('Profile must be release type for the exact app bundle.')
        profile_certificate = bundle_info.get('distribution-certificate')
        if not isinstance(profile_certificate, str):
            raise RuntimeError('Profile distribution certificate is missing.')
        profile_leaf = select_certificate(profile_certificate.encode(), key_hash)
        if certificate_fingerprint(profile_leaf) != cert_hash:
            raise RuntimeError('Profile distribution certificate is not the exact supplied leaf certificate.')
        if args.check:
            print('Public material checks passed. No passwords were read and no APP was signed.')
            return
        store_password = read_password(store_password_file, 'RELEASE_KEYSTORE_PASSWORD')
        key_password = read_password(key_password_file, 'RELEASE_KEY_PASSWORD')
        signed = scratch / 'release-signed.app'
        options = ['--disable-@files', '-jar', jar, 'sign-app', '-mode', 'localSign', '-keystoreFile', paths['key'],
                   '-keystorePwd', store_password, '-keyAlias', args.key_alias, '-keyPwd', key_password,
                   '-signAlg', 'SHA256withECDSA', '-profileFile', paths['profile'], '-appCertFile', paths['cert'],
                   '-inFile', args.input.resolve(), '-outFile', signed]
        argfile = scratch / 'java-sign.args'
        try:
            with argfile.open('x', encoding='utf-8') as handle:
                os.chmod(argfile, 0o600)
                handle.write('\n'.join(java_arg(value) for value in options) + '\n')
            LOG.append(redact(run('Sign APP', [str(java), '@' + str(argfile)]).decode('utf-8', errors='replace')))
        finally:
            argfile.unlink(missing_ok=True)
        require_file(signed, 'fresh signed APP')
        extracted_cert, extracted_profile = scratch / 'verified-cert.cer', scratch / 'verified-profile.p7b'
        sdk('Verify signed APP', ['verify-app', '-inFile', signed, '-outCertChain', extracted_cert, '-outProfile', extracted_profile])
        require_file(extracted_cert, 'APP certificate verification output')
        require_file(extracted_profile, 'APP profile verification output')
        extracted_leaf = select_certificate(extracted_cert.read_bytes(), key_hash)
        if certificate_fingerprint(extracted_leaf) != cert_hash:
            raise RuntimeError('Signed APP leaf certificate differs from the supplied certificate.')
        if extracted_profile.read_bytes() != paths['profile'].read_bytes():
            raise RuntimeError('Signed APP profile differs from the verified release profile.')
        with zipfile.ZipFile(signed) as verified_app:
            if verified_app.testzip() is not None or verified_app.read('entry-default.hap') != inner_hap:
                raise RuntimeError('Signed APP archive or embedded HAP differs unexpectedly.')
        args.output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(signed, args.output)
        result = {'file': str(args.output.resolve()), 'bytes': args.output.stat().st_size,
                  'sha256': hashlib.sha256(args.output.read_bytes()).hexdigest(),
                  'bundleName': BUNDLE, 'versionName': metadata['app']['versionName'],
                  'versionCode': metadata['app']['versionCode'], 'certificateSpkiSha256': key_hash,
                  'certificateSha256': cert_hash,
                  'signed': True, 'sdkVerifyAppPassed': True, 'sdkVerifyProfilePassed': True,
                  'signatureScope': 'APP outer signature, matching default Hvigor assembleApp; embedded HAP unchanged, not claimed signed',
                  'deviceUiValidation': 'not established by signing'}
        args.output.with_suffix('.verification.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
        print('Signed APP and official verification completed: ' + str(args.output))


if __name__ == '__main__':
    os.umask(0o077)
    try:
        main()
    except (RuntimeError, ValueError, OSError, KeyError, zipfile.BadZipFile) as error:
        print('Signing stopped: ' + redact(str(error)), file=sys.stderr)
        sys.exit(1)
    finally:
        if LOG_PATH is not None and not LOG_PATH.is_symlink():
            try:
                LOG_PATH.write_text(redact('\n'.join(LOG)) + '\n', encoding='utf-8')
                os.chmod(LOG_PATH, 0o600)
            except OSError:
                print('Could not save the redacted signing log.', file=sys.stderr)
