#!/usr/bin/env bash
# 环境体检：git / gh / 登录 / 身份 / 仓库状态 / 敏感文件 / 大文件。
# 用法: bash scripts/doctor.sh [仓库目录]（默认当前目录）
set -uo pipefail

DIR="${1:-$PWD}"
cd "$DIR" || exit 1
fail=0; warn=0
ok(){ printf 'PASS  %s\n' "$*"; }
w(){ printf 'WARN  %s\n' "$*"; warn=$((warn+1)); }
bad(){ printf 'FAIL  %s\n' "$*"; fail=$((fail+1)); }
have(){ command -v "$1" >/dev/null 2>&1; }

echo "目录: $PWD"

if have git; then ok "git $(git --version | awk '{print $3}')"; else bad "未安装 git（brew install git / winget install Git.Git）"; fi
if have gh; then ok "gh $(gh --version | head -1 | awk '{print $3}')"; else bad "未安装 gh（brew install gh / winget install GitHub.cli）"; fi

if have gh; then
  if gh auth status >/dev/null 2>&1; then
    login=$(gh api user --jq .login 2>/dev/null || true)
    if [ -n "$login" ]; then ok "已登录 GitHub：$login"; else w "gh 已登录但读不到账号"; fi
  else
    bad "gh 未登录：gh auth login --web"
  fi
fi

name=$(git config --get user.name 2>/dev/null || true)
email=$(git config --get user.email 2>/dev/null || true)
[ -n "$name" ] && ok "user.name = $name" || bad "未设置 user.name"
if [ -z "$email" ]; then
  bad "未设置 user.email"
else
  case "$email" in
    *@users.noreply.github.com) ok "user.email = $email" ;;
    *) w "user.email = $email，可能不属于你的 GitHub 账号；建议用 <数字ID>+<用户名>@users.noreply.github.com" ;;
  esac
fi

if [ -d .git ]; then
  branch=$(git branch --show-current 2>/dev/null || echo '')
  [ -n "$branch" ] && ok "当前分支：$branch" || w "不在任何分支（detached HEAD）"
  remote=$(git remote get-url origin 2>/dev/null || echo '')
  [ -n "$remote" ] && ok "origin = $remote" || w "未配置 origin（首次发布时 gh repo create 会补上）"
  if [ -z "$(git status --porcelain 2>/dev/null)" ]; then ok "工作区干净"; else w "工作区有未提交改动"; fi
  if git rev-parse --verify --quiet "origin/$branch" >/dev/null 2>&1; then
    lc=$(git rev-list --count "$branch"); rc=$(git rev-list --count "origin/$branch")
    if [ "$lc" -lt "$rc" ]; then bad "本地 $branch($lc) 短于 origin/$branch($rc)：禁止强推"; else ok "本地/远端提交数：$lc/$rc"; fi
  fi
  [ -f .env ] && bad "发现 .env（应加入 .gitignore 并移出仓库）" || ok "未发现 .env"
  big=$(find . -path ./.git -prune -o -type f -size +50M -print 2>/dev/null | head -5)
  [ -z "$big" ] && ok "无 >50MB 大文件" || w "存在大文件，改用 release asset：$big"
else
  w "当前目录不是 git 仓库（首次发布可继续）"
fi

if [ -x scripts/preflight-scan.sh ]; then
  echo "--- 脱敏扫描 ---"
  bash scripts/preflight-scan.sh . || w "脱敏扫描有命中，逐条确认后再发布"
else
  w "缺少 scripts/preflight-scan.sh，跳过脱敏扫描"
fi

echo "----"
echo "结果：FAIL=$fail WARN=$warn"
[ "$fail" -eq 0 ] || exit 1
