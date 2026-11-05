#!/usr/bin/env python3
"""Validate only the public static site, for project Pages and custom-domain roots."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urljoin, urlsplit, unquote
import hashlib
import json

WEBSITE = Path(__file__).resolve().parent.parent
DIST = WEBSITE / 'dist'
FILES = {
    '.nojekyll', 'index.html', 'en/index.html', 'privacy/index.html',
    'en/privacy/index.html', 'support/index.html', 'en/support/index.html',
    'assets/icon.svg', 'assets/site.css', 'assets/site.js'
}
EXTERNAL_LINKS = {
    'https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages#data-collection',
    'https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement',
    'mailto:support@oranix.cn'
}
BASES = ['https://bytemain.github.io/soduku-harmony/', 'https://sudoku.oranix.cn/']


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links, self.ids, self.images, self.h1, self.lang = [], set(), [], 0, None
    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if tag == 'html': self.lang = attributes.get('lang')
        if tag == 'h1': self.h1 += 1
        if 'id' in attributes: self.ids.add(attributes['id'])
        if tag == 'img': self.images.append(attributes)
        for key in ['href', 'src']:
            if key in attributes: self.links.append((tag, key, attributes[key]))


def validate_site():
    entries = list(DIST.rglob('*'))
    if any(path.is_symlink() for path in entries):
        raise ValueError('Public files cannot contain symlinks.')
    actual = {str(path.relative_to(DIST)) for path in entries if path.is_file()}
    if actual != FILES:
        raise ValueError('Static publish allowlist mismatch: ' + repr(sorted(actual ^ FILES)))
    pages = {}
    for name in sorted(FILES):
        if name.endswith('.html'):
            page = Page(); text = (DIST / name).read_text(); page.feed(text)
            if page.h1 != 1 or page.lang not in ['zh-CN', 'en']:
                raise ValueError('Invalid page title/language: ' + name)
            if any('alt' not in item for item in page.images):
                raise ValueError('Image alt is missing: ' + name)
            for forbidden in ['PRIVATE KEY', 'keystore-password', '/Users/', '/.ohos/']:
                if forbidden in text: raise ValueError('Non-public content marker in ' + name)
            pages[name] = page
    counts = []
    for base in BASES:
        internal = external = 0
        for name, page in pages.items():
            page_url = urljoin(base, name)
            for tag, attribute, value in page.links:
                if urlsplit(value).scheme or value.startswith('//'):
                    if tag != 'a' or attribute != 'href' or value not in EXTERNAL_LINKS:
                        raise ValueError('Unexpected external reference: ' + value)
                    external += 1; continue
                if value.startswith('/'):
                    raise ValueError('Root-relative URLs break project Pages: ' + value)
                target = urlsplit(urljoin(page_url, value))
                base_parts = urlsplit(base)
                if target.netloc != base_parts.netloc or not target.path.startswith(base_parts.path):
                    raise ValueError('Link escapes the site base: ' + value)
                target_name = unquote(target.path[len(base_parts.path):])
                if target_name.endswith('/') or not target_name: target_name += 'index.html'
                if target_name not in FILES:
                    raise ValueError(name + ' -> missing ' + target_name)
                if target.fragment and (target_name not in pages or target.fragment not in pages[target_name].ids):
                    raise ValueError('Missing anchor: ' + value)
                internal += 1
        counts.append({'base': base, 'internalReferences': internal, 'externalLinks': external, 'passed': True})
    return {'htmlPages': len(pages), 'publicFileCount': len(FILES), 'hostingPaths': counts,
            'files': [{'path': name, 'bytes': (DIST / name).stat().st_size,
                       'sha256': hashlib.sha256((DIST / name).read_bytes()).hexdigest()} for name in sorted(FILES)]}


if __name__ == '__main__':
    report = validate_site()
    (WEBSITE / 'pages-preflight.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({key: value for key, value in report.items() if key != 'files'}, ensure_ascii=False, indent=2))
