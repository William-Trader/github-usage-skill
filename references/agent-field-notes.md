# Agent 实战笔记

来自真实多仓库操作：哪些做法一次过，哪些坑会让整轮返工。

## 1. 高效操作

- **身份只设一次**：`git config --global`，不要逐仓设置；用 `--show-origin --get-all` 确认没有被仓库级配置覆盖。
- **审计与修复分离**：先全量扫描出清单，再逐仓修；不要边扫边改。
- **用 gh，不用匿名 API**：`gh api` 有账号额度（5000/h），匿名只有 60/h，扫到一半 403 会浪费整轮。
- **改前记数**：每个仓库记录 `git rev-list --count <branch>` 与 `origin/<branch>`，重写后比对，数量不等就停下。
- **一个仓库一次闭环**：备份 → 重写 → 核对 → 推送 → `gh api` 验证，做完再下一个；失败即停，不要连续强推。
- **优先 `--force-with-lease`**：`git push --force-with-lease=refs/heads/main:<origin sha> origin main`，远端有新提交时会被拒绝而不是被覆盖。
- **已 checkout 的分支不能 `git branch -f`**：直接推 SHA，`git push --force origin <sha>:refs/heads/main`。
- **批量补元数据**：`gh repo edit --add-topic a,b --description "..."`，比网页点快且可复现。
- **修复提交单独提交**：身份重写与功能改动分成两个 PR/提交，回滚时不互相牵连。
- **脚本先 `--dry-run`**：`quickstart.sh`、`publish.sh` 先跑 `--dry-run` 验证分支与目标，再对真实仓库执行；输出与预期不符就改脚本，不要直接上。
- **扫描命中分真值/示例**：脱敏扫描会命中文档里的示例邮箱、IP、`/Users/<名字>/` 占位符；逐条判断，不要全局替换。

## 2. 真实事故复盘

### 2.1 名字对、邮箱错 → 记到别人名下

- 现象：`William-Trader <william@users.noreply.github.com>`，贡献图没有本人
- 原因：GitHub 按邮箱归属，`william` 是真实存在的另一个账号
- 处理：统一 `331161833+William-Trader@users.noreply.github.com`，重写历史
- 教训：**先看邮箱，再看名字**

### 2.2 本地分支比远端短 → 强推截断历史

- 现象：`w1-quant-board` 60 条变 2 条，`crazy-water-world` 3 条变 2 条
- 原因：本地 `main` 只有 2 条提交，远端有 60 条；`filter-branch --all` 重写的是本地 ref，远端 ref 只是被备份，强推把远端覆盖成短历史
- 恢复：`git reflog show origin/main` 找 `filter-branch: rewrite` 的 SHA → `git push --force origin <sha>:refs/heads/main`
- 防：推送前 `rev-list --count` 比较；永远确认本地不短于远端

### 2.3 `git reset --hard` 冲掉未提交修改

- 现象：同步分支时把正在改的 `index.html` 一起清掉
- 恢复：`git fsck --unreachable --no-reflogs | grep commit` 找 stash commit → `git checkout <stash-sha> -- index.html`
- 防：动历史前 `git stash push -m "wip"`；恢复后用 `git checkout <sha> -- <file>`，不要 reset

### 2.4 filter-branch 静默失效

- 现象：命令返回 0，但邮箱一条没变
- 原因：`--env-filter` 用 `/bin/sh` 执行，`${EMAIL,,}` 是 bash 语法，直接报错退出
- 处理：`ae=$(printf %s "$GIT_AUTHOR_EMAIL" | tr "[:upper:]" "[:lower:]")` 再 `case`
- 防：重写后必须 `git log --format='%ae' | grep -c '<坏邮箱>'`，结果为 0 才算成功

### 2.5 `git log --all` 的假阳性

- 现象：重写后仍能搜到坏邮箱
- 原因：`refs/original/*` 备份仍被 `--all` 包含
- 处理：`git log --exclude='refs/original/*' --all ...`
- 教训：确认干净后再删备份 ref

### 2.6 移动 tag 需要显式 force

- annotated tag 指向被重写的提交时，`git push origin vX` 会被拒绝
- 处理：`git tag -d vX && git tag -a vX -m vX && git push --force origin vX`
- 发版后尽量不再移动 tag；必须移动时在 release notes 说明

## 3. 环境坑

| 环境 | 坑 | 解法 |
|---|---|---|
| zsh | URL 含 `?` 触发 `no matches found` | 整条 URL 加引号 |
| macOS 系统 Python | `urllib` 报 SSL 证书失败 | 用 `curl` 或 `gh api` |
| `gh api --paginate` | 输出是多个 JSON 数组拼接 | 用流式解码器逐个 `raw_decode` |
| `gh repo list` | 默认只返回 30 条 | `--limit 200` |
| 匿名 GitHub API | 60 次/小时 | 全部走 `gh` |
| `git branch -f` | 分支被 worktree 占用时报错 | 推 SHA 到远端 ref |
| `filter-branch` | 速度慢、会留下 `refs/original` | 确认后清理；新项目可用 `git filter-repo` |
| 大仓库 | `--all` 重写耗时 | 先 `git gc`，或改用 `git filter-repo --mailmap` |

## 4. 命令速查

```bash
# 安全强推
git push --force-with-lease=refs/heads/main:$(git rev-parse origin/main) origin main

# 推送前比对提交数
[ "$(git rev-list --count HEAD)" -ge "$(git rev-list --count origin/main)" ] || echo "本地更短，停止"

# 重写后确认坏邮箱清零
git log --exclude='refs/original/*' --all --format='%ae' | grep -c 'william@users.noreply.github.com'

# 恢复被截断的远端（用 reflog 里的 rewrite 提交）
git reflog show origin/main | grep 'filter-branch: rewrite'
git push --force origin <rewrite-sha>:refs/heads/main

# 恢复 reset --hard 冲掉的文件
git fsck --unreachable --no-reflogs | grep commit
git checkout <stash-sha> -- <file>

# 按账号核对归属
bash scripts/verify-remote-authors.sh William-Trader
```

## 5. 推送前检查表

- [ ] `git config --get user.email` 是数字 ID noreply
- [ ] `git status` 干净，或已 stash
- [ ] 本地分支提交数 ≥ `origin/<branch>`
- [ ] 密钥扫描无输出
- [ ] `git remote -v` 指向正确的 owner/repo
- [ ] 用 `--force-with-lease`，不用裸 `--force`
- [ ] 推完 `gh api ... --jq '.[0].author.login'` 等于本人

## 6. Agent 边界

- 不重写第三方 fork 的上游提交
- 不动用户未提交的工作；必须先 stash
- 破坏性操作前打备份 tag / 保留 `refs/original`
- 不把 token、私钥写进命令回显、日志或回复
- 推送失败先诊断（提交数、权限、保护规则），不要连续重试强推
