# 服务器第一次上手：先要钥匙，再动手

新手卡住，九成不是命令不会，而是**没有钥匙就乱试**。本页规定 Agent 在服务器任务开始前必须主动索取 SSH 私钥，并把它安全落地。

## 1. 什么时候主动问

只要用户说到下面任何一类，Agent **立刻**进入本流程，不等用户自己想起来：

- 「部署到服务器」「上线」「放到云主机」
- 「连一下我的服务器」「看看为什么 502」「服务器很慢」
- 「迁到另一台机」「对调两台服务器」
- 任何带 IP、域名、实例名、`ssh` 的请求

先查用户是否已有服务器清单（例如 `~/.ssh/config`、资产库里的调用信息文件）。
**清单存在就直接用清单里的路径**；不存在才问，但必须主动问。

## 2. 一次问全（复制这段话）

> 要连服务器，我需要 4 项，缺一项都会卡：
>
> 1. **服务器 IP 或域名**：
> 2. **登录用户**：Ubuntu 镜像一般是 `ubuntu`，CentOS/部分阿里云镜像一般是 `root`
> 3. **私钥 `.pem` 的文件路径**（或把文件拖进来；**不要**把密钥内容粘贴到聊天）
> 4. **要做什么**：部署哪个项目 / 查什么故障，一句话
>
> 拿到后我会把权限设为 600，先做只读体检，不改任何东西。

三条硬规则：

- 一次问完，不要分五轮挤牙膏。
- 用户说「你看着办」也不能跳过第 3 项；没有私钥就没有访问权。
- 用户只给密码时，先说明「密码登录很多云主机默认已禁用」，再请其提供 `.pem` 或到控制台重置密钥。**不要把密码写进命令历史**。

## 3. 收到私钥后怎么落地

```bash
# 1) 存到固定位置，文件名用小写、无空格
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cp "/下载目录/xxx.pem" ~/.ssh/xxx.pem
chmod 600 ~/.ssh/xxx.pem          # 权限不对 ssh 会直接拒绝

# 2) 验证这把钥匙本身可用（只输出指纹，不打印私钥）
ssh-keygen -y -f ~/.ssh/xxx.pem > /dev/null && echo "key ok"
ssh-keygen -lf ~/.ssh/xxx.pem     # 记录指纹，后续比对

# 3) 首次连接：只读体检
ssh -T -o BatchMode=yes -o ConnectTimeout=10 \
    -i ~/.ssh/xxx.pem ubuntu@<IP> \
    'hostname; whoami; uptime; df -h / | tail -1; free -m | head -2'
```

- `-T`：不要分配终端。交互式 `ssh` 会挂住自动化。
- `BatchMode=yes`：禁止弹密码提示，失败立刻返回，不卡 30 秒。
- 成功标准：输出主机名、用户、开机时长、磁盘、内存；没有 `Permission denied`。

## 4. 建议写进 `~/.ssh/config`

```sshconfig
Host myserver
    HostName 203.0.113.10
    User ubuntu
    IdentityFile ~/.ssh/xxx.pem
    IdentitiesOnly yes
    ServerAliveInterval 30
```

之后统一用 `ssh -T myserver '命令'`，命令短、少出错。多台机器各给一个别名。

## 5. 私钥安全边界

- 绝不把私钥内容回显到聊天、终端输出、日志、README、Git 仓库。
- 绝不把 `.pem` 放进项目目录；统一放 `~/.ssh/`，权限 600。
- 需要交接时传**文件本身**，不传内容；接收方自己 `chmod 600`。
- 怀疑泄漏：先去云控制台**解绑并重建密钥对**，再排查历史记录。删文件不等于失效。
- 不要把私钥写进 skill、脚本、示例配置；只写“路径”。

## 6. 连不上时的判断顺序

| 现象 | 最可能原因 | 处理 |
|---|---|---|
| `Permission denied (publickey)` | 钥匙不对 / 用户不对 / 服务端没这把公钥 | 换清单里指定的那把；确认用户名；到控制台核对密钥对 |
| 卡在 `banner exchange` 后超时 | 短时间高频连接触发限流或 fail2ban | **停止重试**，等 10–15 分钟；期间用业务端口 HTTP 探活 |
| `Connection timed out` | 安全组没放行 22 / IP 变了 | 云控制台看安全组与实例公网 IP |
| `Host key verification failed` | 换过机器，旧指纹还在 | 确认是同一台后 `ssh-keygen -R <IP>` |
| 登录后 `node: not found` | 非交互 SSH 不加载登录 shell | 显式 `export NVM_DIR=$HOME/.nvm; . $NVM_DIR/nvm.sh`，或用绝对路径 |

## 7. 完成标准

- 私钥已在 `~/.ssh/`，`ls -l` 显示 `-rw-------`
- `ssh -T ... 'hostname'` 返回预期主机名
- 指纹已记录（便于确认没连错机器）
- 聊天与日志里没有出现私钥内容
