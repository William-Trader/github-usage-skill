# 服务器日常维护：先看证据，再动手

维护的难点不是命令，而是**判断顺序**。先量服务端与主机负载，再改配置；先本机通，再查公网。

## 1. 每次上线后的四查（1 分钟）

```bash
ssh -T <别名> '
  for u in myapp nginx; do printf "%s: " $u; systemctl is-active $u; done
  df -h / | tail -1
  free -m | head -2
  systemctl --failed --no-pager
'
```

- 服务 `active`、磁盘 < 80%、可用内存 > 15%、没有 failed unit。
- 有 swap 的机器看 `Swap: used` 是否长期高位；长期高位说明内存不够，不是「有 swap 就没事」。

## 2. 日志

```bash
journalctl -u myapp -n 100 --no-pager
journalctl -u myapp --since "30 min ago" --no-pager | grep -iE "error|fail|timeout|refused"
```

- 统一走 systemd，不要 `nohup` 自建日志；否则重启后找不到、也不会轮转。
- 日志暴涨先限流：`/etc/systemd/journald.conf` 设 `SystemMaxUse=200M`，再 `systemctl restart systemd-journald`。
- 第三方通道报错（QQ/微信/Telegram）要看清是**鉴权**、**白名单**还是**限频**；三者处理完全不同。

## 3. 正常更新一个线上服务

固定五步，不跳步：

```bash
# 1) 备份（代码 + 数据 + 配置）
ssh -T <别名> 'tar czf /tmp/myapp-$(date +%F-%H%M).tgz -C /opt/apps myapp'

# 2) 同步代码（不覆盖数据目录）
rsync -az --exclude 'data' --exclude '.env' -e "ssh -i ~/.ssh/xxx.pem" \
  ./myapp/ ubuntu@<IP>:/opt/apps/myapp/

# 3) 重启
ssh -T <别名> 'systemctl restart myapp && sleep 3 && systemctl is-active myapp'

# 4) 验收：本机 → 公网 → 业务真数字
curl -s -o /dev/null -w "local:%{http_code}\n" http://<IP>:3000/

# 5) 失败就回滚
ssh -T <别名> 'rm -rf /opt/apps/myapp && tar xzf /tmp/myapp-<时间>.tgz -C /opt/apps && systemctl restart myapp'
```

原则：**备份先于覆盖**；数据目录单独备份；没有验收不算上线。

## 4. 502 / 页面慢 / 打不开：按这个顺序查

1. **服务活着吗**：`systemctl is-active`，`journalctl -n 50`。
2. **端口在听吗**：`ss -tlnp | grep :3000`。
3. **本机能 curl 通吗**：`curl 127.0.0.1:3000`。
4. **反代指向对吗**：nginx `proxy_pass` 的端口与 `ss` 是否一致。
5. **主机扛得住吗**：`uptime`（load 是否 > 核数）、`free -m`、`df -h`。
6. **公网这一层**：安全组、域名解析、证书。

先量后改。不要一上来就重启，重启会掩盖原因。

## 5. 内存不够的典型信号

- `free -m` 的 `available` 长期 < 100M
- 进程被 OOM 杀：`dmesg -T | grep -i "killed process"`
- 服务反复重启：`systemctl show myapp -p NRestarts`

处理顺序：

1. 关掉不用的常驻服务（先确认没有别的业务依赖）。
2. 加 2G swap 兜底（不能替代内存，只防瞬时报错）。
3. 降并发 / 限制缓存。
4. 升配或拆机。

## 6. 第三方通道维护清单

- **IP 白名单**：迁移机器后，第三方平台（QQ 机器人、支付回调、短信）大多要重新加白名单，否则报「源 IP 不在白名单」。
- **Token 轮换**：换机不是换 token；但泄漏过就必须换。
- **频率限制**：短时间重连会被平台限频，表现在 `400/429`；退避，不要连续重试。
- **出站连通**：服务器能访问外网 ≠ 能访问某个特定域名；用 `curl -I` 实测。

## 7. 定时任务与自启

```bash
systemctl is-enabled myapp           # 开机自启
crontab -l                           # 用户级定时
systemctl list-timers --all          # systemd 定时
```

- 新增 unit 后 `systemctl enable`，否则重启即失效。
- 定时任务里不要写相对路径；用绝对路径和 `--config`。
- 同一任务不要同时存在 cron 与 systemd timer，重复执行最难查。

## 8. 安全基线（新手版）

- SSH 只用密钥，禁用密码：`PasswordAuthentication no`。
- 只放行业务端口 + 22；其余关闭。
- 密钥 600，不放进项目目录、不进 Git。
- 云账号开 MFA；控制台 API key 单独存放。
- 定期 `apt list --upgradable`，安全更新优先。

## 9. 维护完成标准

- 四查全绿
- 更新有备份、有验收、有回滚命令
- 故障有结论：根因、处理、预防，三句话写进记录
