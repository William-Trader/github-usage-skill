# 0 基础：把自己的项目第一次跑在服务器上

目标：从「代码在我电脑上」到「公网能打开、重启能自启、坏了能回滚」。
全程按顺序做，每一步都有完成标准。

## 0. 开工前先拿钥匙

没有私钥就不要往下走。先按 [`server-ssh-access.md`](server-ssh-access.md) 主动索取 `.pem`，落地到 `~/.ssh/` 并 `chmod 600`。

拿到后先做只读体检：

```bash
ssh -T -o BatchMode=yes -i ~/.ssh/xxx.pem ubuntu@<IP> \
  'hostname; whoami; uptime; df -h / | tail -1; free -m | head -2; uname -m'
```

记下：系统架构、磁盘余量、内存、是否已有 swap。1.6G 内存的机器跑 Node + Python + 数据库会紧张，需要 2G swap。

## 1. 先规划，再上传

写下这五项，避免边做边改：

| 项 | 示例 | 说明 |
|---|---|---|
| 代码目录 | `/opt/apps/myapp` | 不要放 `/root` 或 `/home` 下临时目录 |
| 运行用户 | `root`（简单）或专用用户（更稳） | 新手先用 root，能跑通再收紧 |
| 端口 | `3000` | **先查是否被占**，见下一步 |
| 运行时 | Node 24 / Python 3.10 | 必须与项目要求一致 |
| 日志 | `journalctl -u myapp` | 统一走 systemd，不自己写 nohup 日志 |

查端口冲突（必做）：

```bash
ssh -T <别名> 'ss -tlnp | grep -E ":(3000|8080|8081|18789)\b" || echo free'
```

被占用就换端口，不要杀别人的服务。`8080` 是最容易被中转站、面板、代理占用的端口。

## 2. 装运行时（版本要对）

```bash
# Node：项目要 24 就用 24，不要拿系统自带的老版本硬跑
node -v
# 需要新版本：官方二进制或 nvm，不要动系统已有的 node（可能还有别的服务在用）

# Python：确认版本与依赖
python3 -V
```

判断标准：项目 `package.json` 的 `engines`、或代码里的语法/依赖，能被当前版本满足。跑不起来先怀疑版本，不要先改代码。

## 3. 上传代码

```bash
rsync -az --delete \
  --exclude '.git' --exclude 'node_modules' --exclude '.venv' \
  -e "ssh -i ~/.ssh/xxx.pem" \
  ./myapp/ ubuntu@<IP>:/opt/apps/myapp/
```

- 依赖目录不传，服务器上重新装；或者确认架构一致再传。
- **数据库文件不要边写边传**：先停服务，或用 `sqlite3 db ".backup /tmp/db.bak"`。
- 上传后确认目录存在、文件数对得上：`ls | wc -l`。

## 4. 用 systemd 托管（不要 nohup）

```bash
sudo tee /etc/systemd/system/myapp.service >/dev/null <<'EOF'
[Unit]
Description=myapp
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/apps/myapp
Environment=PORT=3000
Environment=NODE_ENV=production
ExecStart=/usr/bin/node /opt/apps/myapp/server.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now myapp
systemctl is-active myapp
```

新手最常犯的三个错：

1. **改了 unit 不 `daemon-reload`** → 还是跑旧配置。
2. **`WorkingDirectory` 不写** → 相对路径全部找不到。
3. **`ExecStart` 用相对命令** → systemd 的 PATH 很短，`node` 可能找不到；写绝对路径。

看日志：

```bash
journalctl -u myapp -n 50 --no-pager
journalctl -u myapp -f          # 实时
```

## 5. 公网访问与两层防火墙

服务「本机 200」不等于「公网能开」。两层都要过：

1. **云安全组**：阿里云/腾讯云控制台放行端口（TCP 3000/3000，来源 0.0.0.0/0）。
2. **主机防火墙**：Ubuntu 的 `ufw status`；没开就代表不拦。

判断公网为什么打不开：

```bash
curl -s -o /dev/null -w "%{http_code}\n" -m 8 http://<公网IP>:3000/
```

| 结果 | 含义 | 处理 |
|---|---|---|
| `000` | 连不上：安全组没放行 / 服务没监听 / 进程崩了 | 先 `ss -tlnp` 看本地有没有监听，再看安全组 |
| `404` | 连上了，路径不对 | 查路由或反代配置 |
| `200` | 通 | 继续验收业务 |

反代模板见 `templates/nginx-site.template`；需要域名 + HTTPS 时，先让域名解析到这台机，再上证书。

## 6. 验收（三层，缺一不可）

```bash
# 1) 服务器本机
curl -s -o /dev/null -w "local:%{http_code}\n" http://127.0.0.1:3000/

# 2) 公网
curl -s -o /dev/null -w "public:%{http_code}\n" http://<公网IP>:3000/

# 3) 业务真数字：页面标题、接口返回、数据库条数，任选一个能证明「不是空壳」
curl -s http://<公网IP>:3000/ | grep -o '<title>[^<]*'
```

再验证自启：

```bash
sudo systemctl restart myapp && sleep 3 && systemctl is-active myapp
```

不要为了验证去随便 `reboot` 生产机；`restart` 足够证明 unit 正常。

## 7. 交付时写清这六项

- 访问地址与端口
- 代码目录
- systemd 服务名
- 日志命令
- 备份位置
- 回滚方法（停新服务 → 起旧服务；或恢复备份目录）

## 8. 完成标准

- `systemctl is-active myapp` = `active`，且 `enabled`
- 本机与公网都 200，页面/接口有真实数据
- 重启服务后自动恢复
- 端口、目录、日志、备份、回滚五项都写进交付说明
