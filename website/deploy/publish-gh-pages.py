#!/usr/bin/env python3
"""Publish the static allowlist to gh-pages in an isolated checkout. Dry-run by default."""
from pathlib import Path
import argparse
import json
import runpy
import shutil
import subprocess
import tempfile

WEBSITE = Path(__file__).resolve().parent.parent
REPO = WEBSITE.parent
VALIDATION = runpy.run_path(str(Path(__file__).with_name('validate-site.py')), run_name='site_validation')
ALLOWED_REMOTES = {'https://github.com/bytemain/soduku-harmony.git',
                   'https://github.com/bytemain/soduku-harmony',
                   'git@github.com:bytemain/soduku-harmony.git'}


def git(directory, *arguments, check=True):
    return subprocess.run(['git', '-C', str(directory), *arguments], check=check,
                          text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--publish', action='store_true', help='Actually commit/push ONLY static files to gh-pages; does not change Pages settings.')
    args = parser.parse_args()
    plan = VALIDATION['validate_site']()
    remote = git(REPO, 'remote', 'get-url', 'origin').stdout.strip()
    if remote not in ALLOWED_REMOTES:
        raise RuntimeError('origin is not the reviewed bytemain/soduku-harmony repository.')
    print(json.dumps({'mode': 'publish' if args.publish else 'dry-run', 'remote': remote,
                      'branch': 'gh-pages', 'publicFiles': [item['path'] for item in plan['files']],
                      'pagesUrl': 'https://bytemain.github.io/soduku-harmony/',
                      'changesCurrentWorktree': False}, ensure_ascii=False, indent=2))
    if not args.publish:
        print('Dry-run only. No commit, push, repository creation, or Pages setting change.')
        return
    with tempfile.TemporaryDirectory(prefix='sudoku-pages-publish-') as temporary:
        checkout = Path(temporary) / 'checkout'
        branch = git(REPO, 'ls-remote', '--exit-code', '--heads', remote, 'refs/heads/gh-pages', check=False)
        if branch.returncode == 0:
            subprocess.run(['git', 'clone', '--single-branch', '--branch', 'gh-pages', '--depth', '1', remote, str(checkout)], check=True)
        elif branch.returncode == 2:
            checkout.mkdir()
            git(checkout, 'init', '--initial-branch', 'gh-pages')
            git(checkout, 'remote', 'add', 'origin', remote)
        else:
            raise RuntimeError('Could not inspect remote gh-pages branch; no push attempted.')
        # Preserve GitHub's future custom-domain commit, without introducing CNAME early.
        cname = None
        existing_cname = checkout / 'CNAME'
        if existing_cname.exists():
            if existing_cname.is_symlink() or not existing_cname.is_file():
                raise RuntimeError('Unexpected remote CNAME entry.')
            cname = existing_cname.read_text().strip()
            if cname != 'sudoku.oranix.cn':
                raise RuntimeError('Unexpected existing custom domain; review before changing this site.')
        for entry in checkout.iterdir():
            if entry.name == '.git': continue
            if entry.is_dir() and not entry.is_symlink(): shutil.rmtree(entry)
            else: entry.unlink()
        for name in sorted(VALIDATION['FILES']):
            target = checkout / name; target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(WEBSITE / 'dist' / name, target)
        if cname: (checkout / 'CNAME').write_text(cname + '\n')
        git(checkout, 'config', 'user.name', 'bytemain')
        git(checkout, 'config', 'user.email', '13938334+bytemain@users.noreply.github.com')
        git(checkout, 'add', '--all')
        changed = git(checkout, 'diff', '--cached', '--quiet', check=False).returncode
        if changed == 0:
            print('gh-pages already contains this static site. No commit or push needed.')
            return
        if changed != 1: raise RuntimeError('Could not review the staged static files.')
        staged = set(git(checkout, 'ls-files').stdout.splitlines())
        if staged != VALIDATION['FILES'] | ({'CNAME'} if cname else set()):
            raise RuntimeError('Publish tree contains unexpected files; no push attempted.')
        git(checkout, 'commit', '-m', 'Publish Not Bad Sudoku website')
        git(checkout, 'push', 'origin', 'HEAD:refs/heads/gh-pages')
        print('Static gh-pages branch pushed. Verify Pages settings/deployment before claiming the site is live.')


if __name__ == '__main__':
    main()
