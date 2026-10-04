# Sentry の unresolved のうち、コメント 0 のものを出す。
# 認証・org・project は ~/.sentryclirc から読む。
# 使い方: python3 .claude/skills/sync/scripts/sentry_uncommented.py
import configparser, json, os, urllib.request

rc = configparser.ConfigParser()
rc.read(os.path.expanduser('~/.sentryclirc'))
tok = rc['auth']['token']
org = rc['defaults']['org']
proj = rc['defaults']['project']

def get(url):
  req = urllib.request.Request(url, headers={'Authorization': f'Bearer {tok}'})
  return json.load(urllib.request.urlopen(req))

issues = get(f'https://sentry.io/api/0/projects/{org}/{proj}/issues/?query=is%3Aunresolved')
print(len(issues), 'unresolved')
for i in issues:
  if not get(f"https://sentry.io/api/0/issues/{i['id']}/comments/"):
    print('コメント0:', i['shortId'], f"count={i['count']}", i['lastSeen'])
