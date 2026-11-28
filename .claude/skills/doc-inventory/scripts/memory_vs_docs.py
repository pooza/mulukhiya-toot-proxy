#!/usr/bin/env python3
"""メモリの中の固有名詞（`...` で囲んだ語）が chubo2 の docs/*.md に出てくるかを数える。

ドキュメント棚卸し（chubo2 docs/doc-maintenance.md の手順 1）の候補を絞るための道具。
既定では infra-note.md 冒頭の「最終ドキュメント棚卸し」の日付より後に更新されたメモリだけを見る。

  python3 memory_vs_docs.py                 # 一覧（未記載の語の数 / 語の数）
  python3 memory_vs_docs.py --terms FILE..  # 指定したメモリの未記載の語と description
  python3 memory_vs_docs.py --since 2026-10-01 --all-projects
"""
import argparse, glob, os, re, sys, time

HOME = os.path.expanduser('~')
DOCS = f'{HOME}/repos/chubo2/docs'
PROJECTS = ['mulukhiya-toot-proxy', 'chubo2', 'makoto2', 'mastodon', 'misskey']

def last_inventory():
    t = open(f'{DOCS}/infra-note.md').read()
    m = re.search(r'最終ドキュメント棚卸し: (\d{4}-\d{2}-\d{2})', t)
    return m.group(1) if m else '1970-01-01'

def memory_dirs(all_projects):
    base = f'{HOME}/.claude/projects'
    if all_projects:
        names = [os.path.basename(d) for d in glob.glob(f'{base}/-home-pooza-repos-*')]
    else:
        names = [f'-home-pooza-repos-{p}' for p in PROJECTS]
    for n in sorted(names):
        d = os.path.realpath(f'{base}/{n}/memory')  # Drive への symlink を辿る
        if os.path.isdir(d):
            yield n.replace('-home-pooza-repos-', ''), d

def terms_of(text):
    return {x for x in re.findall(r'`([^`\n]{4,60})`', text) if not re.fullmatch(r'[\d.\s:-]+', x)}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--since', default=None)
    ap.add_argument('--all-projects', action='store_true')
    ap.add_argument('--terms', nargs='*', help='プロジェクト名/ファイル名 で指定')
    a = ap.parse_args()
    docs = ''.join(open(f).read() for f in glob.glob(f'{DOCS}/*.md'))
    since = a.since or last_inventory()
    cut = time.mktime(time.strptime(since, '%Y-%m-%d'))
    dirs = dict(memory_dirs(a.all_projects))
    if a.terms is not None:
        for spec in a.terms:
            p, n = spec.split('/', 1)
            t = open(f'{dirs[p]}/{n}').read()
            desc = re.search(r'description:\s*(.*)', t)
            miss = sorted(x for x in terms_of(t) if x not in docs)
            print(f'## {spec}\n  {desc.group(1)[:200] if desc else ""}\n  miss: {miss[:25]}')
        return
    print(f'# since {since}（未記載 / 語の数 / 文字数）。F=feedback・user（昇格しない側が多い）、P=project・reference')
    for p, d in dirs.items():
        for f in sorted(glob.glob(f'{d}/*.md')):
            if f.endswith('MEMORY.md') or os.path.getmtime(f) < cut:
                continue
            t = open(f).read()
            kind = 'F' if os.path.basename(f).startswith(('feedback_', 'user_')) else 'P'
            ts = terms_of(t)
            miss = [x for x in ts if x not in docs]
            print(f'{p[:10]:10} {kind} {len(miss):3}/{len(ts):3} {len(t):6} {os.path.basename(f)}')

if __name__ == '__main__':
    sys.exit(main())
