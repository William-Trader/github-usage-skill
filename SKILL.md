---
name: github-usage
description: GitHub 提交/建仓/打包/发版/作者归属修复，0 基础发布与社区贡献的完整流程。
license: MIT
---

# GitHub 使用（Agent 版）

把「本地项目 → GitHub 仓库 → 可安装的发行版」这条路走稳，并保证每一条提交都记在正确的人名下。

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

## 0.5 不熟 GitHub 就先读基础常识

仓库每个页面、分支/Issue/PR/Projects/Discussions/Actions 分别做什么，见 `references/github-basics.md`。给新手解释时先讲清 `main` 分支、Issue 与 PR 的区别，再动手。

完成标准：能用自己的话说清 clone / fork / star / watch 的区别。

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

## 7. 交付前检查

- `gh api repos/<owner>/<repo>/commits --paginate --jq '[.[] | select(.author.login != "<owner>" and (.author.login // "" | endswith("[bot]") | not))] | length'` 为 0
- 远端分支提交数 ≥ 本地（防止 force push 截断历史）
- release 与 tag 都存在，产物可下载
- 仓库无密钥、无绝对路径、无内网 IP
- 客户端/用户按 README 能独立跑通

## 资源

- `references/github-basics.md`：仓库、分支、Issue、PR、Projects、Discussions、Actions、权限与社区常识
- `references/identity-and-auth.md`：身份矩阵、noreply 邮箱规则、认证排错
- `references/repo-lifecycle.md`：建仓、分支、保护、协作者、迁移
- `references/releases-and-packaging.md`：版本号、tag、release、各语言打包
- `references/troubleshooting.md`：错配、截断、拒绝推送、历史恢复
- `references/beginner-path.md`：0 基础用户第一次发布
- `scripts/audit-authorship.sh`：批量扫描错配
- `scripts/fix-authorship.sh`：单仓库重写并安全推送
- `scripts/verify-remote-authors.sh`：按 GitHub 账号逐仓核对
