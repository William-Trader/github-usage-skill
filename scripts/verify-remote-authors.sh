#!/usr/bin/env bash
# 用 GitHub API 逐个仓库核对提交归属。
# 用法: bash scripts/verify-remote-authors.sh <owner> [repo ...]
set -uo pipefail

OWNER="${1:-William-Trader}"
shift || true
if [ "$#" -gt 0 ]; then
  repos=("$@")
else
  mapfile -t repos < <(gh repo list "$OWNER" --limit 200 --json name -q '.[].name')
fi

rc=0
for r in "${repos[@]}"; do
  out=$(gh api "repos/$OWNER/$r/commits?per_page=100" --paginate 2>/dev/null | python3 -c "
import json,sys
raw=sys.stdin.read(); dec=json.JSONDecoder(); i=0; cs=[]
while i < len(raw):
    while i < len(raw) and raw[i] in ' \n\r\t': i += 1
    if i >= len(raw): break
    try: obj, j = dec.raw_decode(raw, i)
    except Exception: break
    if isinstance(obj, list): cs += obj
    i = j
bad = [x['sha'][:8] for x in cs
       if (x.get('author') or {}).get('login') != '$OWNER'
       and not (((x.get('author') or {}).get('login') or '').endswith('[bot]'))]
print(len(cs), len(bad), ','.join(bad[:5]))
")
  read -r total bad sample <<< "$out"
  if [ "${bad:-0}" = "0" ]; then
    printf 'ok   %-42s commits=%s\n' "$r" "$total"
  else
    printf 'BAD  %-42s commits=%s bad=%s %s\n' "$r" "$total" "$bad" "$sample"
    rc=1
  fi
done
exit "$rc"
