# 迁移与对调服务器：服务不变的做法

适合：换机器、加机器、两台机互换角色。
先分清两件事，否则一定返工。

## 0. 先确认「迁移」到底指什么

| 说法 | 能做什么 | 不能做什么 |
|---|---|---|
| 换机器（业务平移） | 把服务搬到新机，改入口 | 跨云交换公网 IP |
| 两台对调（业务互换） | A 的业务去 B，B 的去 A | 让腾讯云和阿里云互换实例/IP |
| 只换域名解析 | 最快，秒级回滚 | 前提是已有域名 |

**跨云（腾讯 ↔ 阿里）无法互换公网 IP/实例身份。** 说「完全对调」时，先把它翻译成「业务对调」。

## 1. 盘点：两台机各自的真实负载

```bash
ssh -T <别名> '
  hostname; uname -m
  free -m | head -2
  df -h / | tail -1
  systemctl list-units --type=service --state=running --no-pager --no-legend | awk "{print \$1}"
  ss -tlnp
'
```

必须记录：

- 每个服务的目录、systemd 名字、端口、运行用户
- 内存实际占用（`ps -eo rss,comm --sort=-rss | head`）
- 端口冲突（两台机常同时用 8080）
- 数据目录与数据库文件
- 第三方依赖：IP 白名单、回调地址、域名

内存算式：目标机可用内存 ≥ 迁移后总 RSS × 1.3。不够就先升配或减服务，**不要靠 swap 硬撑**。

## 2. 备份（两台都做）

```bash
# 远端打包，本地留档
ssh -T <别名> 'sudo tar czf /tmp/mig-$(date +%F).tgz -C /opt apps -C /etc systemd/system/myapp.service'
scp <别名>:/tmp/mig-*.tgz ~/backups/
```

- 配置、unit、nginx、数据、代码，分别备份。
- 数据库按 `server-troubleshooting.md` 第 7 条处理，不要边写边打包。
- 备份落在本地资产库，并记录路径。

## 3. 先在备用端口试跑

不要先停旧服务。新机上：

- 复制代码到新路径（如 `/opt/apps/...`）
- 改掉硬编码的绝对路径
- 用**不同端口**启动，例如旧 8080 → 新 8081
- 本机 `curl 127.0.0.1:新端口` 验证

通过后再进入切换。

## 4. 切换（按依赖顺序）

1. 停旧机的写入型服务（采集、定时任务），避免双写。
2. 做最后一次数据同步（数据库、状态文件）。
3. 启动新机全部服务。
4. 停旧机剩余服务，并 `systemctl disable`。
5. 改入口：DNS、反代、客户端配置、第三方白名单。
6. 逐个验收。

## 5. 验收清单

```bash
# 服务
for u in app-a app-b nginx; do printf "%s: " $u; systemctl is-active $u; done

# 本机
curl -s -o /dev/null -w "local:%{http_code}\n" http://127.0.0.1:3000/

# 公网
curl -s -o /dev/null -w "public:%{http_code}\n" http://<新IP>:3000/
```

- 本机 200 + 公网 200 + 业务真数字（页面标题、接口字段、数据库条数）
- 定时任务在新机 `active`，旧机已 `disabled`
- 第三方通道显示 `connected`，并**实发一条消息**
- 内存/磁盘在安全线内

## 6. 回滚

旧机在验收通过前**不要删**，只 stop + disable。回滚 = 起旧机 + 改回入口。

```bash
ssh -T <旧机> 'systemctl enable --now app-a app-b'
```

## 7. 客户端要不要改

- 服务没换地址：不改，只实测鉴权。
- 服务换了地址：所有 `baseUrl`、书签、回调、白名单逐个改。
- 检查方法：`grep -rn "<旧IP>" <配置目录>`，逐条确认是活配置还是备份文件。

## 8. 最容易漏的五项

1. 端口冲突（两台都占 8080）
2. 硬编码绝对路径（`/home/ubuntu/...`）
3. 运行时版本不一致（Node 20 vs 24）
4. 插件/扩展未重新注册（代码复制了，注册没复制）
5. 第三方 IP 白名单没更新

## 9. 完成标准

- 新机全部服务 active + enabled
- 公网入口实测 200，业务数字正确
- 旧机全部 inactive + disabled，保留可回滚
- 备份路径、回滚命令、验收记录写进交付说明
