#!/usr/bin/env bash
# server-doctor.sh - 服务器连接与健康只读体检
#
# 用法:
#   bash scripts/server-doctor.sh -i ~/.ssh/xxx.pem -u ubuntu -H 203.0.113.10
#   bash scripts/server-doctor.sh -i ~/.ssh/xxx.pem -u root -H 10.0.0.5 -p 2222
#   bash scripts/server-doctor.sh -i ~/.ssh/xxx.pem -u ubuntu -H host --url http://203.0.113.10:3000/
#
# 只读：不安装、不重启、不改配置。退出码非 0 表示有 FAIL。

set -uo pipefail

KEY=""
USER_NAME=""
HOST=""
PORT="22"
URL=""
TIMEOUT="10"

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    -i) KEY="$2"; shift 2 ;;
    -u) USER_NAME="$2"; shift 2 ;;
    -H) HOST="$2"; shift 2 ;;
    -p) PORT="$2"; shift 2 ;;
    --url) URL="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "未知参数: $1"; usage ;;
  esac
done

[ -n "$KEY" ] && [ -n "$USER_NAME" ] && [ -n "$HOST" ] || usage

FAIL=0
WARN=0
pass() { printf "PASS  %s\n" "$1"; }
warn() { printf "WARN  %s\n" "$1"; WARN=$((WARN+1)); }
fail() { printf "FAIL  %s\n" "$1"; FAIL=$((FAIL+1)); }

echo "== 本地检查 =="

if [ -f "$KEY" ]; then
  PERM=$(stat -f '%Lp' "$KEY" 2>/dev/null || stat -c '%a' "$KEY" 2>/dev/null)
  if [ "$PERM" = "600" ] || [ "$PERM" = "400" ]; then
    pass "私钥权限 $PERM"
  else
    fail "私钥权限是 $PERM，应为 600：chmod 600 \"$KEY\""
  fi
else
  fail "找不到私钥：$KEY"
fi

if command -v ssh >/dev/null 2>&1; then
  pass "ssh 可用：$(ssh -V 2>&1)"
else
  fail "本机没有 ssh"
fi

if [ -f "$KEY" ] && ssh-keygen -y -f "$KEY" >/dev/null 2>&1; then
  pass "私钥可解析，指纹：$(ssh-keygen -lf "$KEY" 2>/dev/null | awk '{print $2}')"
else
  fail "私钥无法解析（文件损坏或有口令）"
fi

echo
echo "== 连接检查 =="

TARGET="$USER_NAME@$HOST"
SSH_OPTS=(-T -p "$PORT" -i "$KEY" -o BatchMode=yes -o ConnectTimeout="$TIMEOUT" -o StrictHostKeyChecking=accept-new)

if REMOTE=$(ssh "${SSH_OPTS[@]}" "$TARGET" 'echo __OK__; hostname; whoami; uptime | sed "s/^ *//"' 2>&1); then
  if printf '%s' "$REMOTE" | grep -q '__OK__'; then
    pass "SSH 登录成功"
    printf '%s\n' "$REMOTE" | sed '1d' | sed 's/^/      /'
  else
    fail "SSH 返回异常：$REMOTE"
  fi
else
  fail "SSH 连接失败：$(printf '%s' "$REMOTE" | tail -1)"
fi

if [ "$FAIL" -eq 0 ]; then
  echo
  echo "== 远端健康 =="
  ssh "${SSH_OPTS[@]}" "$TARGET" '
    echo "--- 磁盘"
    df -h / | tail -1
    echo "--- 内存"
    free -m | head -2
    echo "--- 失败的服务"
    systemctl --failed --no-pager --no-legend || true
    echo "--- 监听端口"
    ss -tln | awk "NR>1 {print \$4}" | sort -u | head -30
    echo "--- 内存占用前 5"
    ps -eo rss,comm --sort=-rss | head -6
  ' 2>&1 | sed 's/^/      /'
fi

if [ -n "$URL" ]; then
  echo
  echo "== HTTP 检查 =="
  CODE=$(curl -s -o /dev/null -w '%{http_code}' -m "$TIMEOUT" "$URL" || echo 000)
  case "$CODE" in
    200|201|204|301|302|401|403) pass "$URL -> $CODE" ;;
    000) fail "$URL 连不上（安全组/监听/进程三选一）" ;;
    *) warn "$URL -> $CODE" ;;
  esac
fi

echo
echo "结果: FAIL=$FAIL WARN=$WARN"
[ "$FAIL" -eq 0 ]
