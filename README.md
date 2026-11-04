# GitHub + 服务器 Skill：小白 0 门槛，从发布到上线

> 让 Agent 帮你把项目发到 GitHub、部署到服务器，并且每一步都能验证、能回滚。

两套流程、一个入口：

- **GitHub**：身份、认证、建仓、提交、打包、发版、作者归属修复、社区贡献
- **服务器**：主动接管 SSH 私钥、首次部署、日常维护、故障排查、迁移对调

人也能照着做——**0 基础可以完成第一次发布和第一次上线**。

---

## 它解决什么问题

| 问题 | 典型症状 | 本 skill 的做法 |
|---|---|---|
| **开发者错配** | 推送成功，但贡献图没有你，提交落在陌生人名下 | 强制 `331161833+William-Trader@users.noreply.github.com`；扫描 + 历史重写脚本 |
| **历史截断** | `--force` 之后远端只剩 2 条提交 | 推送前比对本地/远端提交数；`--force-with-lease` |
| **认证混乱** | token 泄漏、403、SSH 没配、把密钥粘进聊天 | gh keyring / 600 文件；最小权限；主动要密钥但不回显 |
| **发版不规范** | 没有 tag、没有 release、产物靠网盘 | 语义化版本 + annotated tag + release asset + 校验和 |
| **没有服务器钥匙** | 有 IP 没 `.pem`，或密钥权限不对，`ssh` 直接拒绝 | 开工先主动索取私钥，落地 600、记录指纹、只读体检 |
| **部署完公网打不开** | 本机 200，公网 `000` | 三层判断：监听 → 安全组 → 主机防火墙；不用猜 |
| **重启就挂** | 手动能跑，开机不启动 | systemd + `enable`；模板里 `WorkingDirectory`/绝对路径都写好 |
| **迁移后全崩** | 换机后端口冲突、路径写死、白名单没改 | 迁移清单：盘点 → 备份 → 备用端口试跑 → 切流 → 验收 → 回滚 |
| **前端上线没证据** | 接口 200 但页面空白、资源 404、移动端错位 | 桌面 + 移动截图 + 控制台错误 + 静态资源检查，全部留档 |
| **小白无从下手** | 不知道从哪一步开始，怕搞坏 | `references/beginner-path.md` 和 `server-first-deploy.md` 一步一条命令 |

**两条最核心的规则**：

1. Git 的归属看**邮箱**，不看名字。
2. 服务器任务的第一步是**拿到 SSH 私钥**，不是敲命令。

---

## 3 分钟从零发布（GitHub）

```bash
gh auth login --web               # 浏览器弹窗，粘贴一次性验证码
cd 你的项目
bash scripts/doctor.sh .          # 体检：环境/身份/敏感文件
bash scripts/quickstart.sh        # 身份→初始化→脱敏→建仓→推送→校验
bash scripts/publish.sh --tag v0.1.0 --notes CHANGELOG.md
```

看到 `OK：提交已归属到你` 即发布成功。

## 3 分钟从零上线（服务器）

```bash
# 1) 把私钥放到 ~/.ssh/，权限 600（Agent 会主动向你要这个文件）
chmod 600 ~/.ssh/xxx.pem

# 2) 只读体检：连接 + 磁盘 + 内存 + 端口 + 失败服务
bash scripts/server-doctor.sh -i ~/.ssh/xxx.pem -u ubuntu -H <IP>

# 3) 按 references/server-first-deploy.md 走：
#    规划目录/端口 → 装运行时 → rsync 代码 → systemd → 防火墙 → 验收
```

看到下面三行才算上线：

```
local:200
public:200
<title>你的项目标题
```

有前端还要留证据：

```bash
bash scripts/server-verify.sh --url http://<IP>:3000/ \
  --api /health --shot evidence/ --report evidence/report.md
```

产出：桌面截图、移动截图、控制台错误 JSON、验收报告。截图必须是真实渲染，不是纯背景色。

---

## Agent 主动要 SSH 私钥（本 skill 的关键能力）

服务器任务开始时，Agent **不等用户提醒**，先查清单；没有就一次问全这四项：

> 1. **服务器 IP 或域名**：
> 2. **登录用户**：Ubuntu 一般是 `ubuntu`，CentOS/部分阿里云镜像一般是 `root`
> 3. **私钥 `.pem` 路径**（或拖文件进来；不要把内容粘贴到聊天）
> 4. **要做什么**：部署哪个项目 / 查什么故障

拿到后固定动作：

```bash
chmod 600 ~/.ssh/xxx.pem
ssh-keygen -y -f ~/.ssh/xxx.pem >/dev/null && echo "key ok"
ssh-keygen -lf ~/.ssh/xxx.pem
ssh -T -o BatchMode=yes -o ConnectTimeout=10 -i ~/.ssh/xxx.pem <用户>@<IP> \
  'hostname; whoami; uptime; df -h / | tail -1; free -m | head -2'
```

硬边界：

- 私钥内容**永不**回显到聊天、日志、README、Git。
- 只写路径，不把私钥复制进项目目录。
- 怀疑泄漏：先去云控制台解绑并重建密钥对，删文件不等于失效。
- 用户只给密码：说明多数云主机已禁用密码登录，请其提供 `.pem`；密码不写进命令历史。

完整流程：[`references/server-ssh-access.md`](references/server-ssh-access.md)

---

## 上线验收：功能检测 + 前端截图

接口 200 只证明服务活着。验收要三层证据：

1. **服务层**：`server-doctor.sh` — 服务、磁盘、内存、端口、失败单元
2. **接口层**：`server-verify.sh` — 状态、耗时、标题、静态资源、API、TLS
3. **界面层**：`server-shot.mjs` — 桌面 + 移动截图、控制台异常

```bash
bash scripts/server-verify.sh \
  --url https://example.com \
  --api /health,/api/status \
  --shot evidence/ \
  --report evidence/report.md
```

```
evidence/
├── <host>-<时间>-desktop.png    # 1440×900，可全页
├── <host>-<时间>-mobile.png     # 390×844，移动 UA
├── <host>-<时间>.json           # 标题、控制台错误、HTTP 错误
└── report.md                    # PASS/WARN/FAIL 清单
```

判读规则：

- 截图必须是真实渲染；纯背景色 = 空白失败
- JSON 里 `exceptions` / `httpErrors` / `failedRequests` 非空，必须查清
- 移动端横向溢出算 UI 缺陷
- 需要登录的页面不截隐私/密钥/订单
- 截图与报告不进公开仓库

没有前端就明确写「本项目无前端」。**没截图的「已上线」等于没验收。**

完整说明：[`references/server-verification.md`](references/server-verification.md)

---

## 能力矩阵

| 环节 | 辅助 | 硬保护 |
|---|---|---|
| 环境体检 | `scripts/doctor.sh` | 身份邮箱不对标 FAIL；本地短于远端标 FAIL |
| 一键发布 | `scripts/quickstart.sh` | 未登录/未确认脱敏直接中止 |
| 脱敏 | `scripts/preflight-scan.sh` | 命中项需逐条确认 |
| 发版 | `scripts/publish.sh` | tag 格式、脏工作区、提交数不足都中止 |
| 归属修复 | `scripts/fix-authorship.sh` | 重写后提交数不一致即停 |
| 交付校验 | `scripts/verify-remote-authors.sh` | 按 `author.login` 判定 |
| 服务器体检 | `scripts/server-doctor.sh` | 私钥权限、连接、磁盘/内存/端口/失败单元 |
| 功能检测 | `scripts/server-verify.sh` | HTTP/耗时/标题/资源/API/TLS，FAIL 非 0 退出 |
| 前端取证 | `scripts/server-shot.mjs` | 桌面 + 移动截图、控制台异常、HTTP 错误 |
| 验收报告 | `templates/verification-report.template.md` | 三层证据 + 回滚信息 |
| 部署托管 | `templates/systemd.service.template` | 绝对路径 + WorkingDirectory + 自启 |
| 反代 | `templates/nginx-site.template` | 超时、转发头、大请求体 |
| 新手答疑 | `references/faq.md`、`server-*.md` | — |

---

## Agent 怎么用

### 安装

```bash
git clone https://github.com/William-Trader/github-usage-skill.git \
  ~/.openclaw/skills/github-usage
```

OpenClaw 读取 `SKILL.md` 的 `description` 自动匹配，不需要额外注册。

### 触发示例

- 「把这个项目发到 GitHub」
- 「为什么我的提交没算进贡献」
- 「部署到我的服务器上」
- 「服务器 502 了，看一下」
- 「把 A 服务器的服务迁到 B」

### Agent 执行顺序

**GitHub**：固定身份 → 查认证 → 建仓/提交 → 打包发版 → 归属核对 → 交付检查

**服务器**：主动要私钥 → 落地 600 → 只读体检 → 规划端口/目录 → 部署 → 验收 → 交付说明

`SKILL.md` 每一步都写了命令和**完成标准**，Agent 不靠猜。

---

## 需求 → 用哪一步

| 你的需求 | 直接看 |
|---|---|
| 第一次发布项目 | `references/beginner-path.md` |
| 提交没算到我的贡献 | `scripts/audit-authorship.sh` → `scripts/fix-authorship.sh` |
| 强推后历史变短 | `references/troubleshooting.md` 第 2 节 |
| 打 tag / 做 release | `references/releases-and-packaging.md` |
| 第一次部署到服务器 | `references/server-first-deploy.md` |
| 没有私钥 / ssh 连不上 | `references/server-ssh-access.md` |
| 部署完公网打不开 | `references/server-maintenance.md` 第 5 节 |
| 服务重启就挂 | `references/server-first-deploy.md` 第 4 节 |
| 服务器报错查原因 | `references/server-troubleshooting.md` |
| 迁机 / 两台对调 | `references/server-migration.md` |
| 上线验收 / 前端截图 | `references/server-verification.md` |
| 多仓库统一身份 | `references/identity-and-auth.md` |

---

## 仓库结构

```
github-usage-skill/
├── SKILL.md                          # Agent 主流程（GitHub + 服务器，命令 + 完成标准）
├── README.md                         # 人看的入口
├── references/
│   ├── github-basics.md              # 仓库/分支/Issue/PR/Actions 常识
│   ├── faq.md                        # 27 个新手高频问题
│   ├── pre-publish-interview.md      # 发布前必问、许可证、脱敏
│   ├── agent-field-notes.md          # 高效批处理、事故复盘
│   ├── identity-and-auth.md          # 身份矩阵、noreply、认证排错
│   ├── repo-lifecycle.md             # 建仓、分支、保护、归档
│   ├── releases-and-packaging.md     # 版本号、tag、release、打包
│   ├── troubleshooting.md            # 错配、截断、拒绝推送
│   ├── beginner-path.md              # 0 基础第一次发布
│   ├── server-ssh-access.md          # 主动索取并接管 SSH 私钥
│   ├── server-first-deploy.md        # 0 基础第一次部署
│   ├── server-maintenance.md         # 维护、更新、502、内存、安全
│   ├── server-troubleshooting.md     # 真实故障对照表
│   ├── server-migration.md           # 迁移 / 对调
│   └── server-verification.md        # 功能检测与前端截图
├── templates/                        # README / CHANGELOG / PR / Issue / gitignore
│   ├── systemd.service.template      # 服务托管模板
│   ├── nginx-site.template           # 反向代理模板
│   └── verification-report.template.md # 上线验收报告
└── scripts/
    ├── doctor.sh                     # GitHub 环境体检
    ├── quickstart.sh                 # 一键发布
    ├── publish.sh                    # 一键发版
    ├── preflight-scan.sh             # 脱敏扫描
    ├── audit-authorship.sh           # 批量扫描错配
    ├── fix-authorship.sh             # 重写 + 安全强推
    ├── verify-remote-authors.sh      # 按账号核对
    ├── server-doctor.sh              # 服务器连接与健康只读体检
    ├── server-verify.sh              # HTTP/API/静态资源/TLS 功能检测
    └── server-shot.mjs               # 桌面 + 移动截图与控制台错误
```

---

## GitHub 基础常识（新手先读）

| 你可能在问 | 一句话答案 |
|---|---|
| 仓库是什么 | 代码 + 历史 + Issue/PR/Actions/Projects 的协作载体 |
| branch 是什么 | 指向提交线的可移动指针，`main` 是主线 |
| Issue 和 PR 区别 | Issue 是待办/bug；PR 是改好代码请求合并 |
| star / fork / watch | 收藏表态 / 复制仓库 / 订阅通知 |
| Actions 是什么 | CI/CD，自动跑测试、构建、发版 |
| 社区怎么参与 | fork → 分支 → 提交 → PR |

完整版：[`references/github-basics.md`](references/github-basics.md)

## 发布前先问三件事

**不替用户默认公开。** 先问、先扫、再发布：

1. **可见性与授权**：公开 + MIT / Apache-2.0 / PolyForm 非商业 / 私有
2. **脱敏范围**：全仓扫描 / 只扫工作区 / 不脱敏（默认全仓）
3. **发布内容**：只发源码 / 源码 + 产物 / 源码 + 示例数据

```bash
bash scripts/preflight-scan.sh .
```

历史提交里的密钥必须**轮换**，清理历史不能替代轮换。

## 服务器上线前先问三件事

1. **私钥**：路径、用户、IP（缺一不可）
2. **端口与目录**：用哪个端口、放哪个目录、运行用户
3. **验收方式**：哪个 URL / 哪个接口 / 哪个业务数字算成功

---

## 真实案例

### 案例 1：17 个仓库、80 条提交记错人

全部重写并推送后，用 GitHub API 逐仓核对 `bad=0`。其中两个仓库因本地分支比远端短，首次强推把 60/3 条历史推成 2 条，最终从 `filter-branch` 的 rewritten ref 恢复。**这就是 `fix-authorship.sh` 里「提交数不一致直接中止」存在的原因。**

### 案例 2：两台服务器业务对调

真实迁移中遇到的问题，全部写进了 `server-migration.md` 与 `server-troubleshooting.md`：

- 两台机都用 8080 → 必须有一个换端口
- 程序复制过去，插件注册没过去 → 功能缺失
- 换机后第三方平台报「源 IP 不在白名单」→ 控制台加白名单
- 目标机 1.6G 内存跑整套服务 → 需要 swap，且必须盯 `available`
- 客户端 base URL 到底要不要改 → 先确认服务是否真的换址

### 案例 3：上线验收发现「假成功」

- 服务 `active`、接口 200，但页面截图是空白 → 前端构建产物没上传
- 静态资源脚本抓出 `echarts.min.js` 404 → 图表全空
- 移动截图横向溢出 → 表格固定宽度

这些都不是「应该没问题」，是截图和资源检查当场拆穿的。验收的价值在这里。

---

## 安全边界

- 只重写**你自己**的仓库；第三方 fork 的上游提交不动
- 强推前核对提交数，优先 `--force-with-lease`
- 私钥只存路径，不存内容；权限 600；不进仓库
- 密钥泄漏先 revoke/重建，再清历史
- 本 skill 不保存任何凭据

---

## 贡献

Issue / PR 都欢迎。提交前确认作者邮箱是你的 GitHub noreply 地址。

## License

MIT
