#!/usr/bin/env bash
# 0 基础一键发布：身份 → 初始化 → 脱敏 → 建仓 → 推送 → 校验。
# 用法: bash scripts/quickstart.sh [--dir DIR] [--repo NAME] [--visibility public|private]
#        [--license mit|apache-2.0|none] [--description TEXT] [--dry-run] [--yes]
set -uo pipefail

DIR="$PWD"; REPO_NAME=""; VIS="public"; LICENSE="mit"; DESC=""; DRY=0; YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="${2:?}"; shift 2;;
    --repo) REPO_NAME="${2:?}"; shift 2;;
    --visibility) VIS="${2:?}"; shift 2;;
    --license) LICENSE="${2:?}"; shift 2;;
    --description) DESC="${2:?}"; shift 2;;
    --dry-run) DRY=1; shift;;
    --yes) YES=1; shift;;
    *) echo "未知参数: $1" >&2; exit 1;;
  esac
done

cd "$DIR" || exit 1
echo "目录: $PWD"

ask(){ # ask <prompt> <default>
  local v
  if [ "$YES" -eq 1 ]; then printf '%s' "$2"; return; fi
  read -r -p "$1 [$2]: " v || true
  printf '%s' "${v:-$2}"
}

command -v git >/dev/null || { echo "缺少 git"; exit 1; }
command -v gh >/dev/null || { echo "缺少 gh：brew install gh 或 winget install GitHub.cli"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "未登录：先运行 gh auth login --web"; exit 1; }

LOGIN=$(gh api user --jq .login)
UID_NUM=$(gh api user --jq .id)
NO_REPLY="${UID_NUM}+${LOGIN}@users.noreply.github.com"

echo "账号: $LOGIN"
cur_email=$(git config --get user.email || true)
if [ "$cur_email" != "$NO_REPLY" ]; then
  if [ "$YES" -eq 1 ]; then
    git config --global user.email "$NO_REPLY"; git config --global user.name "$LOGIN"
    echo "已设置身份: $LOGIN <$NO_REPLY>"
  else
    read -r -p "把全局 git 身份设为 $LOGIN <$NO_REPLY>？[Y/n]: " a || true
    case "${a:-y}" in
      y|Y|"") git config --global user.email "$NO_REPLY"; git config --global user.name "$LOGIN"; echo "已设置";;
      *) echo "保留现有身份：$cur_email（注意可能不归属到你）";;
    esac
  fi
fi

[ -n "$REPO_NAME" ] || REPO_NAME=$(ask "仓库名" "$(basename "$PWD")")
[ -n "$DESC" ] || DESC=$(ask "一句话描述" "项目说明")
if [ "$YES" -eq 0 ]; then
  read -r -p "可见性 public/private [$VIS]: " v || true; VIS="${v:-$VIS}"
  read -r -p "许可证 mit/apache-2.0/none [$LICENSE]: " v || true; LICENSE="${v:-$LICENSE}"
fi

if [ "$DRY" -eq 1 ]; then
  echo "--- dry-run ---"
  echo "将创建: $LOGIN/$REPO_NAME ($VIS, license=$LICENSE)"
  echo "目录: $PWD"
  echo "身份: $(git config --get user.name) <$(git config --get user.email)>"
  exit 0
fi

if [ ! -d .git ]; then git init -b main >/dev/null; echo "已初始化 git"; fi

if [ ! -f .gitignore ]; then
  if [ -f package.json ]; then cp "$(dirname "$0")/../templates/gitignore-node" .gitignore
  elif [ -f pyproject.toml ] || [ -f requirements.txt ]; then cp "$(dirname "$0")/../templates/gitignore-python" .gitignore
  else cp "$(dirname "$0")/../templates/gitignore-macos" .gitignore; fi
  echo "已生成 .gitignore"
fi

if [ ! -f LICENSE ] && [ "$LICENSE" != "none" ]; then
  if gh api "/licenses/$LICENSE" --jq .body > LICENSE 2>/dev/null; then echo "已写入 LICENSE ($LICENSE)"; else echo "许可证下载失败，跳过"; fi
fi

if [ ! -f README.md ]; then
  tpl="$(dirname "$0")/../templates/README.template.md"
  [ -f "$tpl" ] && sed "1s/.*/# $REPO_NAME/" "$tpl" > README.md && echo "已生成 README.md"
fi

echo "--- 脱敏扫描 ---"
if [ -x "$(dirname "$0")/preflight-scan.sh" ]; then
  if ! bash "$(dirname "$0")/preflight-scan.sh" . >/tmp/gh-skill-scan.$$ 2>&1; then
    cat /tmp/gh-skill-scan.$$ | tail -20
    if [ "$YES" -eq 0 ]; then
      read -r -p "扫描有命中，确认已逐条检查并继续？[y/N]: " a || true
      case "${a:-n}" in y|Y) ;; *) echo "已中止；处理后再运行。"; rm -f /tmp/gh-skill-scan.$$; exit 2;; esac
    else
      echo "扫描有命中，--yes 模式下中止。"; rm -f /tmp/gh-skill-scan.$$; exit 2
    fi
  fi
  rm -f /tmp/gh-skill-scan.$$
fi

git add -A
if git diff --cached --quiet; then echo "没有新文件需要提交"; else git commit -m "feat: 初始提交" >/dev/null && echo "已提交"; fi

gh repo create "$LOGIN/$REPO_NAME" "--$VIS" --source . --remote origin --push --description "$DESC" >/dev/null || {
  echo "建仓失败：检查仓库名是否已存在，或改用 gh repo view $LOGIN/$REPO_NAME"; exit 3; }

login_check=$(gh api "repos/$LOGIN/$REPO_NAME/commits" --jq '.[0].author.login' 2>/dev/null || true)
echo "----"
echo "仓库: https://github.com/$LOGIN/$REPO_NAME"
echo "作者归属: ${login_check:-未知}"
[ "$login_check" = "$LOGIN" ] && echo "OK：提交已归属到你" || echo "注意：归属不是 $LOGIN，按 references/agent-field-notes.md 修复"
echo "下一步：打 tag 发版 → bash scripts/publish.sh --tag v0.1.0"
