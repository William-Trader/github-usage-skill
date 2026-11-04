#!/usr/bin/env bash
# server-verify.sh — 线上功能检测（只读）
#
# 用法：
#   bash scripts/server-verify.sh --url http://203.0.113.10:3000/
#   bash scripts/server-verify.sh --url https://example.com --api /health,/api/status
#   bash scripts/server-verify.sh --url http://host:3000/ --shot evidence/ --report evidence/report.md
#
# 检查：DNS/TCP、HTTP 状态与耗时、标题与非空、gzip、安全头、
#       同源静态资源、API 状态与 JSON、TLS 到期、（可选）前端截图。
# 只读：不发 POST、不改服务器。退出码非 0 表示有 FAIL。

set -uo pipefail

URL=""
API_LIST=""
SHOT_DIR=""
REPORT=""
TIMEOUT="15"
EXPECT="200"

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --url) URL="$2"; shift 2 ;;
    --api) API_LIST="$2"; shift 2 ;;
    --shot) SHOT_DIR="$2"; shift 2 ;;
    --report) REPORT="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --expect) EXPECT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "未知参数: $1"; usage ;;
  esac
done

[ -n "$URL" ] || usage

case "$URL" in
  http://*|https://*) ;;
  *) URL="http://$URL" ;;
esac

FAIL=0
WARN=0
LINES=()
pass() { printf "PASS  %s\n" "$1"; LINES+=("| PASS | $1 |"); }
warn() { printf "WARN  %s\n" "$1"; LINES+=("| WARN | $1 |"); WARN=$((WARN+1)); }
fail() { printf "FAIL  %s\n" "$1"; LINES+=("| FAIL | $1 |"); FAIL=$((FAIL+1)); }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
BODY="$TMP/body.html"
HEADERS="$TMP/headers.txt"

# ---------- URL 拆解 ----------
HOSTPORT=$(printf '%s' "$URL" | sed -E 's#^https?://##; s#/.*$##')
HOST=${HOSTPORT%%:*}
BASE=$(printf '%s' "$URL" | sed -E 's#(^https?://[^/]+).*#\1#')
SCHEME=${URL%%://*}
[ "$SCHEME" = "$URL" ] && SCHEME="http"
if printf '%s' "$HOSTPORT" | grep -q ':'; then
  PORT=${HOSTPORT##*:}
else
  [ "$SCHEME" = "https" ] && PORT=443 || PORT=80
fi

echo "== 目标 =="
echo "URL : $URL"
echo "HOST: $HOST"
echo

# ---------- DNS ----------
if printf '%s' "$HOST" | grep -Eq '^[0-9.]+$'; then
  pass "目标是 IP，跳过 DNS"
else
  if command -v dig >/dev/null 2>&1; then
    IP=$(dig +short "$HOST" | tail -1)
  else
    IP=$(nslookup "$HOST" 2>/dev/null | awk '/^Address: /{print $2}' | tail -1)
  fi
  if [ -n "${IP:-}" ]; then
    pass "DNS 解析 $HOST -> $IP"
  else
    fail "DNS 解析失败：$HOST"
  fi
fi

# ---------- TCP ----------
if command -v nc >/dev/null 2>&1; then
  if nc -z -w 5 "$HOST" "$PORT" 2>/dev/null; then
    pass "TCP $HOST:$PORT 可连接"
  else
    fail "TCP $HOST:$PORT 连不上（安全组/监听/网络）"
  fi
fi

# ---------- HTTP ----------
read -r CODE TIME_TOTAL SIZE_DOWNLOAD EFFECTIVE_URL < <(
  curl -sS -L --max-time "$TIMEOUT" \
    -A "server-verify/1.0" \
    -D "$HEADERS" -o "$BODY" \
    -w '%{http_code} %{time_total} %{size_download} %{url_effective}' \
    "$URL" 2>"$TMP/curl.err"
) || true

if [ -z "${CODE:-}" ]; then
  fail "curl 失败：$(tail -1 "$TMP/curl.err" 2>/dev/null)"
else
  if [ "$CODE" = "$EXPECT" ]; then
    pass "HTTP $CODE（期望 $EXPECT），总耗时 ${TIME_TOTAL}s，体积 ${SIZE_DOWNLOAD}B"
  else
    fail "HTTP $CODE（期望 $EXPECT）"
  fi

  if printf '%s' "$EFFECTIVE_URL" | grep -q '^https://'; then
    pass "最终地址 HTTPS：$EFFECTIVE_URL"
  elif printf '%s' "$EFFECTIVE_URL" | grep -q '^http://'; then
    warn "最终仍是 HTTP：$EFFECTIVE_URL（上线建议 HTTPS）"
  fi

  if printf '%s' "$TIME_TOTAL" | awk '{exit !($1 > 3)}'; then
    warn "首字节总耗时 ${TIME_TOTAL}s 偏慢（>3s）"
  fi

  TITLE=$(grep -o '<title>[^<]*' "$BODY" 2>/dev/null | head -1 | sed 's/<title>//')
  if [ -n "${TITLE:-}" ]; then
    pass "页面标题：$TITLE"
  else
    fail "页面没有 <title>（可能是空壳或返回了错误页）"
  fi

  BYTES=$(wc -c < "$BODY" | tr -d ' ')
  if [ "${BYTES:-0}" -lt 200 ]; then
    fail "响应体只有 ${BYTES}B，疑似空页面"
  else
    pass "响应体 ${BYTES}B"
  fi

  if grep -qi '^content-encoding:.*gzip\|^content-encoding:.*br' "$HEADERS"; then
    pass "已启用压缩"
  else
    warn "未检测到 gzip/br 压缩"
  fi

  for h in x-content-type-options x-frame-options strict-transport-security; do
    if grep -qi "^$h:" "$HEADERS"; then
      pass "安全头 $h 存在"
    else
      warn "缺少安全头 $h（加不加取决于业务）"
    fi
  done
fi

# ---------- 同源静态资源 ----------
if [ -s "$BODY" ]; then
  echo
  echo "== 静态资源（最多 6 个）=="
  ASSETS=$(grep -oE '(src|href)="[^"]+"' "$BODY" 2>/dev/null \
    | sed -E 's/^(src|href)="//; s/"$//' \
    | grep -E '\.(css|js|mjs)(\?|$)' \
    | grep -v '^https\?://' \
    | head -6)
  if [ -z "$ASSETS" ]; then
    warn "页面没有引用同源 css/js（可能是纯内联或未渲染）"
  else
    while IFS= read -r asset; do
      [ -z "$asset" ] && continue
      case "$asset" in
        /*) ASSET_URL="$BASE$asset" ;;
        *) ASSET_URL="${URL%/*}/$asset" ;;
      esac
      ACODE=$(curl -s -o /dev/null --max-time "$TIMEOUT" -w '%{http_code}' "$ASSET_URL" 2>/dev/null)
      [ -z "$ACODE" ] && ACODE=000
      if [ "$ACODE" = "200" ]; then
        pass "资源 $ACODE $asset"
      else
        fail "资源 $ACODE $asset"
      fi
    done <<< "$ASSETS"
  fi
fi

# ---------- API ----------
if [ -n "$API_LIST" ]; then
  echo
  echo "== API =="
  BASE=$(printf '%s' "$URL" | sed -E 's#(^https?://[^/]+).*#\1#')
  OLDIFS=$IFS; IFS=','
  for p in $API_LIST; do
    IFS=$OLDIFS
    case "$p" in
      http*) API_URL="$p" ;;
      /*) API_URL="$BASE$p" ;;
      *) API_URL="$BASE/$p" ;;
    esac
    API_OUT="$TMP/api.out"
    ACODE=$(curl -s -o "$API_OUT" --max-time "$TIMEOUT" -w '%{http_code}' "$API_URL" || echo 000)
    if [ "$ACODE" = "200" ]; then
      if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$API_OUT" 2>/dev/null; then
        pass "API 200 JSON $p"
      else
        warn "API 200 但非 JSON：$p"
      fi
    else
      fail "API $ACODE $p"
    fi
  done
  IFS=$OLDIFS
fi

# ---------- TLS ----------
if [ "$SCHEME" = "https" ]; then
  echo
  echo "== TLS =="
  END=$(echo | openssl s_client -connect "$HOST:443" -servername "$HOST" 2>/dev/null \
    | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  if [ -n "${END:-}" ]; then
    END_EPOCH=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$END" +%s 2>/dev/null || date -d "$END" +%s 2>/dev/null || echo 0)
    NOW=$(date +%s)
    DAYS=$(( (END_EPOCH - NOW) / 86400 ))
    if [ "$DAYS" -le 0 ]; then
      fail "证书已过期：$END"
    elif [ "$DAYS" -lt 14 ]; then
      warn "证书 ${DAYS} 天后到期：$END"
    else
      pass "证书有效，剩余 ${DAYS} 天"
    fi
  else
    warn "无法读取证书信息"
  fi
fi

# ---------- 截图 ----------
if [ -n "$SHOT_DIR" ]; then
  echo
  echo "== 前端截图 =="
  if command -v node >/dev/null 2>&1; then
    if node "$(dirname "$0")/server-shot.mjs" --url "$URL" --out "$SHOT_DIR" --both; then
      pass "截图完成：$SHOT_DIR"
    else
      warn "截图脚本返回非 0（看上面的异常/HTTP 错误）"
    fi
  else
    warn "本机没有 node，跳过截图"
  fi
fi

# ---------- 报告 ----------
if [ -n "$REPORT" ]; then
  mkdir -p "$(dirname "$REPORT")"
  {
    echo "# 上线验收报告"
    echo
    echo "- URL：$URL"
    echo "- 时间：$(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "- 结果：FAIL=$FAIL WARN=$WARN"
    echo
    echo "| 结果 | 检查项 |"
    echo "|---|---|"
    printf '%s\n' "${LINES[@]}"
  } > "$REPORT"
  echo
  echo "报告: $REPORT"
fi

echo
echo "结果: FAIL=$FAIL WARN=$WARN"
[ "$FAIL" -eq 0 ]
