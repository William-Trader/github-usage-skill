#!/usr/bin/env bash
# 发布前脱敏扫描：凭据、IP、绝对路径、身份信息、敏感文件。
# 用法: bash scripts/preflight-scan.sh [目录]（默认当前仓库）
set -uo pipefail

ROOT="${1:-$PWD}"
cd "$ROOT" || exit 1
hits=0

section() { printf '\n== %s ==\n' "$1"; }

# 1) 明显凭据
section "凭据/密钥"
matches=$(grep -rInE --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build --exclude=preflight-scan.sh \
  'sk-[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{20,}|xox[baprs]-[0-9A-Za-z-]{10,}|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY' . 2>/dev/null | head -40)
if [ -n "$matches" ]; then echo "$matches"; hits=$((hits+1)); else echo "  (none)"; fi

# 2) 公网 IP 与内网域名
section "网络地址"
matches=$(grep -rInE --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
  '\b(([0-9]{1,3}\.){3}[0-9]{1,3})\b|\.internal\b|\.localdomain\b' . 2>/dev/null \
  | grep -vE '127\.0\.0\.1|0\.0\.0\.0|version|127\.0|192\.168\.|10\.' | grep -v '<' | head -20)
if [ -n "$matches" ]; then echo "$matches"; hits=$((hits+1)); else echo "  (none)"; fi

# 3) 本机绝对路径
section "绝对路径"
matches=$(grep -rInE --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build --exclude=preflight-scan.sh \
  '/Users/[^/ ]+/|C:\\\\Users\\\\|/home/[^/ ]+/' . 2>/dev/null | head -20)
if [ -n "$matches" ]; then echo "$matches"; hits=$((hits+1)); else echo "  (none)"; fi

# 4) 邮箱与手机号
section "身份信息"
matches=$(grep -rInE --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|\b1[3-9][0-9]{9}\b' . 2>/dev/null \
  | grep -vE 'noreply@github\.com|@example\.(com|org)|@users\.noreply|git@github\.com' | head -20)
if [ -n "$matches" ]; then echo "$matches"; hits=$((hits+1)); else echo "  (none)"; fi

# 5) 敏感文件
section "敏感文件"
matches=$(find . -path ./.git -prune -o -type f \
  \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.key' -o -name 'id_rsa*' -o -name '*.p12' -o -name '*.sqlite' -o -name '*.db' \) \
  -print 2>/dev/null | grep -vE '\.env\.example|\.env\.sample' | head -20)
if [ -n "$matches" ]; then echo "$matches"; hits=$((hits+1)); else echo "  (none)"; fi

printf '\n----\n'
if [ "$hits" -eq 0 ]; then
  echo "脱敏扫描通过：未发现明显敏感内容。"
  exit 0
fi
echo "发现 $hits 类可疑内容。逐条与用户确认后再发布；历史提交里的凭据必须轮换。"
exit 1
