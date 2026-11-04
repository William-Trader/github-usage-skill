# 服务器排错对照表（真实踩过）

按「现象 → 原因 → 处理」查。每条都来自实际故障，不是理论。

## 1. SSH 连接类

### 卡在 `banner exchange` 后超时

- 原因：短时间高频连接触发限流/fail2ban，或链路抖动。**不是主机宕机**。
- 处理：停止重试，等 10–15 分钟；期间用业务端口 HTTP 探活；必要时从云控制台解封。
- 教训：连续重试会加重封禁。

### `Permission denied (publickey)`

- 原因：钥匙不对、用户名不对、服务端没登记公钥。
- 处理：按清单逐把试，`BatchMode=yes` 避免卡在密码提示：

```bash
for k in ~/.ssh/*.pem; do
  ssh -T -i "$k" -o BatchMode=yes -o ConnectTimeout=8 ubuntu@<IP> hostname && break
done
```

### 登录后 `node: not found` / `npm: not found`

- 原因：非交互 SSH 不加载登录 shell，nvm/pnpm 的 PATH 不生效。
- 处理：命令里显式加载，或用绝对路径：

```bash
ssh -T <别名> 'export NVM_DIR=$HOME/.nvm; . $NVM_DIR/nvm.sh; node -v'
```

## 2. 命令在本地被吃掉

### `awk '{print $1}'` 到远端变空

- 原因：双引号让**本地** shell 先展开 `$1`，远端收到空字符串。
- 处理：外层用单引号，或把脚本流过去：

```bash
ssh -T <别名> 'awk "{print \$1}" file'      # 转义
ssh -T <别名> 'bash -s' < script.sh          # 或整体流式执行
```

## 3. 公网打不开

```bash
curl -s -o /dev/null -w "%{http_code}\n" -m 8 http://<IP>:<PORT>/
```

| 结果 | 判断 |
|---|---|
| `000` | 三层之一：安全组没放行 / 服务没监听 / 进程崩了 |
| `404` | 已连上，路由或反代路径不对 |
| `502` | 反代活着，后端死了或端口错 |
| `200` | 通 |

判别先后：`systemctl is-active` → `ss -tlnp` → 本机 `curl 127.0.0.1` → 安全组。
**端口通 ≠ SSH 可用**，也 ≠ 业务正常。

## 4. 端口冲突

- 现象：新服务起不来，`bind: address already in use`；或页面显示了别的项目。
- 原因：`8080`、`3000`、`80` 被中转站、面板、旧服务占用。
- 处理：先 `ss -tlnp` 看占用者，再决定换端口；不要直接杀不认识的进程。

## 5. systemd 起不来，但手动能跑

- `WorkingDirectory` 没写 → 相对路径找不到
- `ExecStart` 用 `node` 而非绝对路径 → PATH 太短
- 环境变量只在 shell 里 export 过 → unit 里没有
- 改了 unit 没 `daemon-reload`
- 用户不对（`User=ubuntu` 但目录属 root 且不可读）

```bash
systemctl status myapp --no-pager -l
journalctl -u myapp -n 50 --no-pager
```

## 6. 复制/搬迁后「插件没装」

- 现象：程序能起，但功能缺失，日志提示 `plugin not installed`。
- 原因：只复制了程序目录，插件/扩展的注册信息不在其中，或路径变了。
- 处理：按程序自己的包管理器重新安装并注册（例如 `openclaw plugins install <pkg> --force`），不要手改注册表。
- 教训：**代码可复制，运行态注册要重建**。

## 7. SQLite 边写边打包 → 数据库损坏

- 现象：`tar` 报 `file changed as we read it`，恢复后 `database disk image is malformed`。
- 原因：数据库正在写入时被复制。
- 处理：先停服务，或用备份命令：

```bash
sqlite3 app.db ".backup /tmp/app.db.bak"
```

- 验收：`sqlite3 file.db "pragma quick_check;"` 输出 `ok`。

## 8. 迁移后客户端到底要不要改

先确认**服务是否真的换了地址**。

- 中转站没搬：客户端 base URL 一行都不用改，实测鉴权即可。
- 服务搬了：所有引用旧 IP 的配置、书签、回调、白名单都要改；裸 IP 是最容易漏的。
- 判断方法：`grep -rn "<旧IP>" 配置目录`，逐个确认真实生效，而不是只看备份文件。

## 9. 第三方平台 IP 白名单

- 现象：`401 Unauthorized`、`接口访问源IP不在白名单`。
- 原因：换机器后出口 IP 变了，平台侧只认旧 IP。
- 处理：到平台控制台把新公网 IP 加进白名单；加完重启通道，确认 `connected` 再测消息。
- 注意：有的平台还有频率限制，短时间重连会 `400/429`，退避后再试。

## 10. 内存不足 / 服务反复重启

```bash
free -m
dmesg -T | grep -i "killed process"
systemctl show myapp -p NRestarts
```

- 1.6G/2G 机器同时跑 Node + Python + 网关很容易触顶；加 2G swap 只能兜底。
- 先停非必要服务，再考虑升配；不要靠 `Restart=always` 掩盖 OOM。

## 11. 时间/时区不一致

- 现象：日志时间差 8 小时、定时任务不在预期时间触发。
- 处理：`timedatectl set-timezone Asia/Shanghai`；核对 `date`。
- 定时任务用系统时区；跨时区协作时在注释里写清。

## 12. 排错纪律

- 一次只改一个变量，改完立刻验证。
- 保留证据：命令、输出、时间戳；不要凭记忆复述。
- 涉及删除、覆盖、重启生产：先备份，再执行，并准备好回滚命令。
- 不确定就说不确定；不要用「应该好了」结案。
