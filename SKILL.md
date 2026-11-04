---
name: github-usage
description: GitHub 提交/建仓/打包/发版/作者归属修复，以及服务器部署/调试/维护/迁移、上线验收与前端截图、主动接管 SSH 私钥，0 基础从项目到上线。
license: MIT
---

# GitHub + 服务器（Agent 版）

把「本地项目 → GitHub 仓库 → 服务器上线」这条路走稳：提交记在正确的人名下，服务能部署、能维护、能回滚。

服务器部分的第一动作不是敲命令，是**主动拿到 SSH 私钥**（见第 9 节）。

## 何时用

- 用户要把本地项目发到 GitHub、新建仓库、公开或私有发布
- 提交后贡献图没有自己，或提交被记到别人名下
- 要给 agent 配置 GitHub 身份，避免项目/开发者错配
- 需要打 tag、写 release、上传构建产物
- 0 基础用户问「怎么发布项目」「怎么给开源项目提 PR」

## 0. 先固定身份（每次动手前第一条）

```bash
git config --global user.name "William-Trader"
git config --global user.email "331161833+William-Trader@users.noreply.github.com"
```

- 禁止 `william@users.noreply.github.com`：GitHub 上真的存在 `william` 账号，提交会记到别人名下。
- 禁止裸 `William` 或不带数字 ID 的邮箱。
- 用户名式 `William-Trader@users.noreply.github.com` 也能归属，但统一用 `331161833+` 形式最稳。
- 只看仓库级配置会漏：先查 `git config --show-origin --get-all user.email`。

完成标准：`git config --global --get user.email` 输出 `331161833+William-Trader@users.noreply.github.com`。

## 0.2 发布前询问（强制，先问再做）

发布是不可逆的公开动作。**没有问清楚之前，不建仓库、不推送。**

一次问完三项，每项给推荐值：

| # | 必问 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 可见性与授权 | 公开 + MIT / 公开 + Apache-2.0 / 公开 + PolyForm 非商业 / 私有 | 工具类选公开 + MIT；有商业价值选 PolyForm 非商业 |
| 2 | 脱敏范围 | 全仓扫描并清理 / 只扫工作区 / 不脱敏 | 全仓扫描（含历史提交、README、release 正文） |
| 3 | 发布内容 | 只发源码 / 源码 + release 产物 / 源码 + 示例数据 | 只发源码；产物走 release |

先跑扫描，把命中项逐条给用户看：

```bash
bash scripts/preflight-scan.sh .
```

- 凭据、公网 IP、绝对路径、真实身份、敏感文件，逐类确认
- 历史提交里的密钥必须**轮换**，清理历史不能替代轮换
- LICENSE 选择与脱敏清单见 `references/pre-publish-interview.md`

用户说「你看着办」时用最保守组合：私有 + 无 LICENSE + 全量脱敏，并明确告知，等确认后再转公开。

完成标准：三项都有明确答复，扫描命中项已处理，用户说「可以发布」。

## 0.5 不熟 GitHub 就先读基础常识

仓库每个页面、分支/Issue/PR/Projects/Discussions/Actions 分别做什么，见 `references/github-basics.md`。给新手解释时先讲清 `main` 分支、Issue 与 PR 的区别，再动手。

完成标准：能用自己的话说清 clone / fork / star / watch 的区别。

## 0.9 一键路径（0 基础推荐）

先体检，再发布，最后发版：

```bash
gh auth login --web                            # 首次：浏览器弹窗，粘贴一次性码
bash scripts/doctor.sh .                       # 环境与仓库体检
bash scripts/quickstart.sh                     # 身份→初始化→脱敏→建仓→推送→校验
bash scripts/publish.sh --tag v0.1.0 --notes CHANGELOG.md
```

- `quickstart.sh` 会交互确认仓库名、可见性、许可证；`--dry-run` 只看计划，`--yes` 全默认非交互。
- `publish.sh` 会在有未提交改动、tag 格式不对、本地短于远端时直接中止。
- 模板在 `templates/`（README / CHANGELOG / CONTRIBUTING / PR / Issue / .gitignore），脚本会自动取用。

完成标准：`quickstart` 输出「OK：提交已归属到你」，`publish` 输出 release URL 与 assets 数量。

## 1. 认证与权限

```bash
gh auth status          # 期望：Logged in to github.com account <本人账号>
ssh -T git@github.com   # 可选；HTTPS 足够完成全部操作
```

- 凭据只放 gh keyring / 600 权限文件；不在命令、README、日志、聊天里回显。
- 未登录时用 `gh auth login --web`，让用户在浏览器完成；不要让用户把 token 粘进聊天。
- 权限不够时先看 `gh auth status` 的 scopes，再决定重登，不要反复试推。

完成标准：`gh api user --jq .login` 返回预期账号。

## 2. 建仓并首推

```bash
git init -b main
git add -A
git commit -m "feat: 初始提交"
gh repo create <owner>/<repo> --public --source . --remote origin --push
```

- 建库前先确认目标 owner 与仓库名；同名仓库已存在时，`gh repo create` 会失败而不是覆盖，这是保护。
- 私有项目把 `--public` 换成 `--private`。
- 首推后立刻核对归属，不要等发版时才发现。

完成标准：`gh api repos/<owner>/<repo>/commits --jq '.[0].author.login'` 等于本人账号。

## 3. 提交卫生

- 一次提交只做一件事；消息用 `feat: / fix: / docs: / chore: / refactor:` 前缀。
- 提交前扫密钥：

```bash
git diff --cached | grep -Ei 'sk-[A-Za-z0-9]|gho_|ghp_|AIza|BEGIN (RSA|OPENSSH) PRIVATE KEY' && echo "疑似密钥，停止提交"
```

- `.env`、`node_modules/`、构建产物写进 `.gitignore`；真实密钥只在服务器 600 文件里。
- 大文件不进库：单文件 > 50MB 用 release asset，不要塞进 git 历史。

完成标准：`git status --short` 只剩预期改动；密钥扫描无输出。

## 4. 打包与发版

版本用语义化：修 bug 升 PATCH，加功能升 MINOR，破坏兼容升 MAJOR。

```bash
# 1) 同步所有版本号（package.json / pyproject.toml / 版本常量）
# 2) 提交并打 annotated tag
git tag -a v5.1.0 -m "v5.1.0"
git push origin main
git push origin v5.1.0
# 3) 建 release 并上传产物
gh release create v5.1.0 dist/app.zip --title "v5.1.0" --notes-file CHANGELOG.md
```

- 先跑测试再打 tag；tag 一旦推送就不要移动，除非明确知道代价。
- 产物命名带平台与架构：`app-macos-arm64.zip`、`app-windows-x64.zip`。
- 细节见 `references/releases-and-packaging.md`。

完成标准：`gh release view vX --json tagName,assets` 能看到 tag 与全部产物。

## 5. 作者归属审计与修复（本 skill 的核心）

扫描所有本地仓库：

```bash
bash scripts/audit-authorship.sh "$HOME/openclaw资产库"
```

修复单个仓库：

```bash
bash scripts/fix-authorship.sh /path/to/repo "william@users.noreply.github.com,william@local,si@local"
```

固定顺序，任何一步都不能跳：

1. `git fetch` 并记录远端每个分支的提交数
2. 备份旧 ref，确认工作区干净（脏就先 stash）
3. `filter-branch` 批量重写 author/committer
4. 核对重写后提交数与重写前一致
5. 用 `--force-with-lease` 推送每个受影响分支与 tag
6. `gh api` 校验 `author.login` 全部等于本人

- `filter-branch --env-filter` 在 POSIX sh 下执行，写 `${email,,}` 这类 bash 小写展开会报错并让整次重写静默失效；用 `$(printf %s "$GIT_AUTHOR_EMAIL" | tr "[:upper:]" "[:lower:]")` 再做 `case` 匹配，重写完先 grep 坏邮箱计数确认真的变了。
- `filter-branch --all` 只重写本地 ref，`refs/remotes/origin/*` 只是被快照备份；本地分支比远端短时直接强推会用短历史覆盖远端。此时从 `git reflog show origin/<branch>` 取 `filter-branch: rewrite` 那条的 SHA，用 `git push --force origin <sha>:refs/heads/<branch>` 推重写后的远端 tip。
- 每个仓库先比较 `git rev-list --count <branch>` 与 `git rev-list --count origin/<branch>`，本地更短就停下，先同步或改用远端分支再重写。
- 工作区有未提交改动时先 stash 再动历史；恢复后不要 `git reset --hard`，从 stash commit 取回文件：`git checkout <stash-sha> -- <file>`。
- 只按 GitHub API 的 `author.login` 判定是否需要重写；网页端编辑产生的提交可能用账号主邮箱或显示名（例如 `William <qq邮箱>`），只要 `login` 是本人就别为了统一邮箱再改历史。
- 用户会直接在 GitHub 网页改 README，从而产生远端新提交；推送前先 `git fetch`，被拒时 `git rebase origin/main` 合并，不要用强推覆盖用户的网页修改。

禁止：不看本地/远端提交数就 `--force`；`git reset --hard` 前不 stash；把第三方 fork 的上游提交一起重写。

完成标准：`bash scripts/verify-remote-authors.sh <owner>` 输出全部 `bad=0`。

## 6. 社区贡献

```bash
gh repo fork <upstream>/<repo> --clone
git switch -c fix/具体问题
# 小步提交，只改必要文件
git push -u origin fix/具体问题
gh pr create --title "fix: ..." --body "问题、原因、验证方式"
```

- 不重写上游历史，不 force push 别人的分支。
- 一个 PR 只解决一个问题；附带复现步骤与验证结果。

## 7. 高效操作与事故复盘

批量审计、脚本化修复、以及本机真实踩过的坑（历史截断、未提交修改丢失、filter-branch 静默失效）都记在 `references/agent-field-notes.md`。做多仓库操作前先读它，能省掉整轮返工。

完成标准：能复述「本地分支短于远端时禁止强推」与「重写后必须比对提交数」两条硬规则。

## 8. 交付前检查

- `gh api repos/<owner>/<repo>/commits --paginate --jq '[.[] | select(.author.login != "<owner>" and (.author.login // "" | endswith("[bot]") | not))] | length'` 为 0
- 远端分支提交数 ≥ 本地（防止 force push 截断历史）
- release 与 tag 都存在，产物可下载
- 仓库无密钥、无绝对路径、无内网 IP
- 客户端/用户按 README 能独立跑通

## 9. 服务器任务：开工先主动要钥匙（强制）

任务涉及服务器——部署、上线、排障、维护、迁移、对调——**先执行本节，不要等用户想起来**。

### 9.1 先查，没有再问

- 先查 `~/.ssh/config`、资产库里的服务器调用信息、用户已给的路径。
- 清单存在：直接用清单里的主机/用户/密钥路径。
- 清单不存在：**主动**发出下面这段，一次问全。

> 要连服务器，我需要 4 项，缺一项都会卡：
> 1. **服务器 IP 或域名**：
> 2. **登录用户**：Ubuntu 镜像一般是 `ubuntu`，CentOS/部分阿里云镜像一般是 `root`
> 3. **私钥 `.pem` 的文件路径**（或把文件拖进来；**不要**把密钥内容粘贴到聊天）
> 4. **要做什么**：部署哪个项目 / 查什么故障，一句话
>
> 拿到后我会设为 600 权限，先做只读体检，不改任何东西。

### 9.2 收到私钥后的固定动作

```bash
chmod 600 ~/.ssh/xxx.pem
ssh-keygen -y -f ~/.ssh/xxx.pem >/dev/null && echo "key ok"
ssh-keygen -lf ~/.ssh/xxx.pem    # 记录指纹
ssh -T -o BatchMode=yes -o ConnectTimeout=10 -i ~/.ssh/xxx.pem <用户>@<IP> \
  'hostname; whoami; uptime; df -h / | tail -1; free -m | head -2'
```

- 一律非交互：`-T` + `BatchMode=yes`；交互式 `ssh` 会挂住自动化。
- 只输出指纹，不打印私钥内容。
- 用户只给密码：说明多数云主机已禁用密码登录，请其提供 `.pem` 或到控制台重置密钥；不把密码写进命令历史。

### 9.3 硬边界

- 私钥内容不进聊天、日志、README、Git、skill；只写路径。
- 怀疑泄漏先去云控制台解绑并重建密钥对；删文件不等于失效。
- 连不上先按 `references/server-ssh-access.md` 第 6 节的判断顺序，不要连续重试触发限流。

完成标准：`ls -l` 显示 `-rw-------`；`ssh -T ... 'hostname'` 返回预期主机名；聊天与日志无密钥内容。

## 10. 首次部署（0 基础）

固定顺序：体检 → 规划 → 装运行时 → 传代码 → systemd → 防火墙 → 验收。

```bash
# 只读体检
bash scripts/server-doctor.sh -i ~/.ssh/xxx.pem -u ubuntu -H <IP>

# 端口冲突先查
ssh -T <别名> 'ss -tlnp | grep -E ":(3000|8080)\b" || echo free'
```

三条新手铁律：

- **版本要对**：项目要 Node 24 就不要用系统自带老版本硬跑。
- **用 systemd，不用 nohup**：`WorkingDirectory`、绝对路径 `ExecStart`、`daemon-reload` 三个都不能漏。
- **两层防火墙**：云安全组 + 主机 ufw；公网 `000` 先查监听再来查安全组。

验收必须三层：本机 `curl` → 公网 `curl` → 业务真数字（标题/字段/条数）；有前端还要截图，见第 14 节。

完整步骤与模板：`references/server-first-deploy.md`、`templates/systemd.service.template`、`templates/nginx-site.template`。

完成标准：服务 `active` + `enabled`；本机与公网都 200；重启后自动恢复。

## 11. 维护

每次上线后四查：`systemctl is-active`、`journalctl`、`df -h`、`free -m`；再看 `systemctl --failed`。

更新线上服务固定五步：**备份 → 同步（排除数据目录）→ 重启 → 验收 → 失败回滚**。

502/慢/打不开按顺序查：服务活着吗 → 端口在听吗 → 本机 curl 通吗 → 反代指向对吗 → 主机负载 → 公网/域名/证书。

第三方通道（QQ 机器人等）要看三类错：鉴权、IP 白名单、频率限制；处理方式完全不同。

细节：`references/server-maintenance.md`。

## 12. 迁移与对调

先说清「对调」指什么：

- 跨云（腾讯 ↔ 阿里）**不能互换公网 IP/实例**，只能做业务平移。
- 业务对调：A 的服务去 B，B 的去 A；先盘点、再备份、先备用端口试跑、最后切流。
- 内存算式：目标机可用内存 ≥ 迁移后总 RSS × 1.3；不够先升配，不靠 swap 硬撑。

先盘端口冲突（两台常同时用 8080）、硬编码绝对路径、运行时版本、插件注册、第三方 IP 白名单。

旧机验收通过前只 stop + disable，不删；回滚 = 起旧机 + 改回入口。

细节：`references/server-migration.md`。

## 13. 服务器排错

按现象查：SSH 限流、`node: not found`、本地 shell 吃掉 `$1`、公网 `000/404/502`、端口冲突、systemd 手动能跑、插件未注册、SQLite 边写边打包、白名单、OOM、时区。

完整对照表：`references/server-troubleshooting.md`。每条都是真实故障，不是理论。

## 14. 上线验收：功能检测 + 前端截图

「接口 200」不等于「用户能用」。三层证据，缺一层不算完成：

```bash
# 服务层
bash scripts/server-doctor.sh -i ~/.ssh/xxx.pem -u ubuntu -H <IP>

# 接口层 + 界面层（一条命令）
bash scripts/server-verify.sh --url https://example.com \
  --api /health,/api/status --shot evidence/ --report evidence/report.md
```

`server-verify.sh` 检查：DNS/TCP、HTTP 状态与耗时、标题、响应体非空、压缩、安全头、同源静态资源、API JSON、TLS 到期。

`server-shot.mjs` 用本机 Chrome/Edge 的 DevTools Protocol 截图（服务器不用装浏览器），输出：

- 桌面 1440×900、移动 390×844，可全页
- 控制台异常、HTTP 错误、失败请求清单（JSON）

判读规则：

- 截图必须是真实渲染；纯背景色 = 空白失败。
- JSON 里 `exceptions` / `httpErrors` / `failedRequests` 任一非空，查清再宣布完成。
- 移动截图横向溢出算 UI 缺陷。
- 需要登录的页面用测试账号，不截隐私/密钥/订单。
- 截图与报告按日期归档，**不进公开仓库**。

无前端时明确写「本项目无前端」，不要含糊。

细节：`references/server-verification.md`、`templates/verification-report.template.md`。

完成标准：`FAIL=0`；桌面与移动截图真实渲染、数据非空；控制台无异常。

## 15. 服务器交付前检查

- [ ] 私钥 600，未出现在聊天/日志/仓库
- [ ] 服务 `active` 且 `enabled`，`systemctl --failed` 为空
- [ ] 本机 200 + 公网 200 + 业务真数字
- [ ] 有前端：桌面 + 移动截图已归档，控制台无异常；无前端已说明
- [ ] 磁盘 < 80%，可用内存 > 15%，swap 未被长期打满
- [ ] 备份路径、日志命令、回滚命令已写进交付说明
- [ ] 第三方通道已实发一条消息验证

## 资源

- `references/faq.md`：27 个新手高频问题
- `scripts/doctor.sh`：环境/身份/仓库/敏感文件体检
- `scripts/quickstart.sh`：0 基础一键发布
- `scripts/publish.sh`：一键打 tag + release + 上传产物
- `templates/`：README、CHANGELOG、CONTRIBUTING、PR、Issue、.gitignore 模板
- `references/pre-publish-interview.md`：发布前必问项、许可证选择、脱敏清单与确认单
- `scripts/preflight-scan.sh`：发布前脱敏扫描（凭据/IP/路径/身份/敏感文件）
- `references/agent-field-notes.md`：高效批处理、真实事故复盘、命令速查、推送前检查表
- `references/github-basics.md`：仓库、分支、Issue、PR、Projects、Discussions、Actions、权限与社区常识
- `references/identity-and-auth.md`：身份矩阵、noreply 邮箱规则、认证排错
- `references/repo-lifecycle.md`：建仓、分支、保护、协作者、迁移
- `references/releases-and-packaging.md`：版本号、tag、release、各语言打包
- `references/troubleshooting.md`：错配、截断、拒绝推送、历史恢复
- `references/beginner-path.md`：0 基础用户第一次发布
- `references/server-ssh-access.md`：主动索取并安全接管 SSH 私钥
- `references/server-first-deploy.md`：0 基础第一次把项目跑在服务器上
- `references/server-maintenance.md`：日常维护、更新、502 诊断、内存与安全
- `references/server-troubleshooting.md`：真实故障对照表
- `references/server-migration.md`：迁移/对调，服务不变的做法
- `references/server-verification.md`：功能检测与前端截图取证
- `scripts/server-doctor.sh`：连接与健康只读体检
- `scripts/server-verify.sh`：HTTP/API/静态资源/TLS 功能检测
- `scripts/server-shot.mjs`：桌面 + 移动截图与控制台错误采集
- `templates/verification-report.template.md`：上线验收报告模板
- `templates/systemd.service.template`、`templates/nginx-site.template`：服务与反代模板
- `scripts/audit-authorship.sh`：批量扫描错配
- `scripts/fix-authorship.sh`：单仓库重写并安全推送
- `scripts/verify-remote-authors.sh`：按 GitHub 账号逐仓核对
