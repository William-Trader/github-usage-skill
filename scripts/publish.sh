#!/usr/bin/env bash
# 一键发版：检查 → 打 tag → 推送 → 建 release → 上传产物 → 校验。
# 用法: bash scripts/publish.sh --tag v1.0.0 [--notes CHANGELOG.md]
#        [--assets "dist/*.zip"] [--title "v1.0.0"] [--dry-run] [--yes]
set -uo pipefail

TAG=""; NOTES=""; ASSETS=""; TITLE=""; DRY=0; YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --tag) TAG="${2:?}"; shift 2;;
    --notes) NOTES="${2:?}"; shift 2;;
    --assets) ASSETS="${2:?}"; shift 2;;
    --title) TITLE="${2:?}"; shift 2;;
    --dry-run) DRY=1; shift;;
    --yes) YES=1; shift;;
    *) echo "未知参数: $1" >&2; exit 1;;
  esac
done

[ -n "$TAG" ] || { echo "用法: publish.sh --tag v1.2.3 [--notes CHANGELOG.md] [--assets 'dist/*']"; exit 1; }
case "$TAG" in v[0-9]*.[0-9]*.[0-9]*) ;; *) echo "tag 必须形如 v1.2.3"; exit 1;; esac

[ -d .git ] || { echo "当前目录不是 git 仓库"; exit 1; }
BRANCH=$(git branch --show-current)
[ -n "$BRANCH" ] || { echo "detached HEAD，先切回分支"; exit 1; }
REMOTE=$(git remote get-url origin 2>/dev/null || true)
[ -n "$REMOTE" ] || { echo "未配置 origin，先 gh repo create 或 git remote add"; exit 1; }

if [ -n "$(git status --porcelain)" ]; then
  echo "工作区有未提交改动，先提交或 stash 再发版"; exit 2
fi

git fetch --quiet origin || true
if git rev-parse --verify --quiet "origin/$BRANCH" >/dev/null; then
  lc=$(git rev-list --count "$BRANCH"); rc=$(git rev-list --count "origin/$BRANCH")
  if [ "$lc" -lt "$rc" ]; then echo "本地 $BRANCH($lc) 短于远端($rc)，先同步"; exit 3; fi
fi

echo "准备发布 $TAG（分支 $BRANCH）"
[ -n "$ASSETS" ] && echo "产物: $ASSETS"
if [ "$DRY" -eq 1 ]; then echo "--- dry-run，未执行 ---"; exit 0; fi
if [ "$YES" -eq 0 ]; then
  read -r -p "确认发布 $TAG？[y/N]: " a || true
  case "${a:-n}" in y|Y) ;; *) echo "已取消"; exit 0;; esac
fi

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "tag $TAG 已存在，直接用于 release"
else
  git tag -a "$TAG" -m "$TAG"
  echo "已创建 tag $TAG"
fi

git push origin "$BRANCH" || exit 4
git push origin "$TAG" 2>/dev/null || git push --force origin "$TAG"

TITLE="${TITLE:-$TAG}"
args=(release create "$TAG" --title "$TITLE")
if [ -n "$NOTES" ] && [ -f "$NOTES" ]; then args+=(--notes-file "$NOTES"); else args+=(--generate-notes); fi
# shellcheck disable=SC2206
[ -n "$ASSETS" ] && args+=($ASSETS)

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "release 已存在，改为上传产物"
  [ -n "$ASSETS" ] && gh release upload "$TAG" $ASSETS --clobber
else
  gh "${args[@]}" || { echo "release 创建失败"; exit 5; }
fi

echo "----"
gh release view "$TAG" --json tagName,url,assets --jq '"release: \(.tagName) \(.url) assets=\(.assets|length)"'
echo "完成。检查清单：版本号同步、CHANGELOG 更新、产物可下载。"
