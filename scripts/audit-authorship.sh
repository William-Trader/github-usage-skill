#!/usr/bin/env bash
# 扫描本地仓库里不可归属到 GitHub 账号的提交邮箱。
# 用法: bash scripts/audit-authorship.sh [扫描根目录]
set -uo pipefail

ROOT="${1:-$PWD}"
# 常见“看似正常、实际不归属”的邮箱；按需补充
BAD_RE='^(william@users\.noreply\.github\.com|william@local|william@localhost|si@local|w@local|w1@william\.local|ubuntu@localhost\.localdomain|[^@[:space:]]+@[^@[:space:]]*\.local|[^@[:space:]]+@localhost)$'

found=0
while IFS= read -r repo; do
  cd "$repo" || continue
  bad=$(git log --exclude='refs/original/*' --all --format='%ae' 2>/dev/null \
        | grep -E "$BAD_RE" | sort | uniq -c || true)
  [ -z "$bad" ] && continue
  found=$((found + 1))
  remote=$(git remote get-url origin 2>/dev/null || echo none)
  echo "=== $repo"
  echo "    remote: $remote"
  echo "$bad" | sed 's/^/    /'
done < <(find "$ROOT" -maxdepth 6 -type d -name .git \
          -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null \
          | sed 's|/\.git$||' | sort)

if [ "$found" -eq 0 ]; then
  echo "OK: 未发现不可归属的提交邮箱。"
else
  echo "----"
  echo "共 $found 个仓库需要修复。示例："
  echo "  bash scripts/fix-authorship.sh <repo> \"william@users.noreply.github.com,william@local\""
fi
