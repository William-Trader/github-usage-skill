#!/usr/bin/env bash
# 把指定坏邮箱的提交重写为指定身份，并在提交数一致的前提下安全强推。
# 用法: bash scripts/fix-authorship.sh <repo> "<bad1>,<bad2>" [name] [email]
set -euo pipefail

REPO="${1:?用法: fix-authorship.sh <repo> \"<bad1>,<bad2>\" [name] [email]}"
BAD="${2:?缺少坏邮箱列表，逗号分隔}"
NAME="${3:-William-Trader}"
EMAIL="${4:-331161833+William-Trader@users.noreply.github.com}"

cd "$REPO"
echo "仓库: $PWD"

if ! git diff --quiet || ! git diff --cached --quiet; then
  git stash push -m "pre-author-fix-$(date +%s)" >/dev/null
  echo "已 stash 未提交改动"
fi

git fetch --all --quiet || true

# 关键保护：本地分支不能比远端短，否则强推会截断历史
declare -A BEFORE
for b in $(git for-each-ref --format='%(refname:short)' refs/heads); do
  up="origin/$b"
  git rev-parse --verify --quiet "$up" >/dev/null || continue
  lc=$(git rev-list --count "$b")
  rc=$(git rev-list --count "$up")
  BEFORE["$b"]=$lc
  if [ "$lc" -lt "$rc" ]; then
    echo "中止：本地 $b 只有 $lc 条提交，远端 $up 有 $rc 条。先同步或改用正确分支。" >&2
    exit 2
  fi
done

git tag -f "backup/pre-author-fix-$(date +%Y%m%d-%H%M%S)" HEAD >/dev/null
echo "已打本地备份 tag"

BAD_CASE=$(printf '%s' "$BAD" | tr ',' '|')
export BAD_CASE NAME EMAIL
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --env-filter '
ae=$(printf %s "$GIT_AUTHOR_EMAIL" | tr "[:upper:]" "[:lower:]")
ce=$(printf %s "$GIT_COMMITTER_EMAIL" | tr "[:upper:]" "[:lower:]")
case "$ae" in $BAD_CASE)
  export GIT_AUTHOR_NAME="$NAME"; export GIT_AUTHOR_EMAIL="$EMAIL";;
esac
case "$ce" in $BAD_CASE)
  export GIT_COMMITTER_NAME="$NAME"; export GIT_COMMITTER_EMAIL="$EMAIL";;
esac
' --tag-name-filter cat -- --all >/dev/null

for b in "${!BEFORE[@]}"; do
  after=$(git rev-list --count "$b")
  if [ "$after" -ne "${BEFORE[$b]}" ]; then
    echo "中止：$b 重写后提交数 $after ≠ 重写前 ${BEFORE[$b]}" >&2
    exit 3
  fi
done

if git log --exclude='refs/original/*' --all --format='%ae' | grep -E "^($BAD_CASE)$" >/dev/null; then
  echo "仍有坏邮箱残留，请检查" >&2
  exit 4
fi

for b in "${!BEFORE[@]}"; do
  git push --force-with-lease="refs/heads/$b:$(git rev-parse "origin/$b")" origin "$b" || {
    echo "推送 $b 失败：远端可能已有新提交，先 fetch 再重试" >&2; exit 5; }
done
git push --force origin --tags >/dev/null 2>&1 || true

echo "完成。建议再跑: bash scripts/verify-remote-authors.sh <owner> $b"
echo "备份 ref 仍在 refs/original/* 与 backup/pre-author-fix-*，确认无误后再清理。"
