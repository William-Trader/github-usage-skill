# 0 基础：从本地文件夹到 GitHub 发行版

两条路，任选一条。**推荐一键路径**，卡住了再看手动路径。

## 路线 A：一键（推荐）

```bash
cd 你的项目
bash <skill目录>/scripts/quickstart.sh
```

脚本会依次做：

1. 检查 git / gh 是否安装、是否登录
2. 把身份设成你的 `<数字ID>+<用户名>@users.noreply.github.com`
3. 问仓库名、描述、可见性、许可证（都有默认值，直接回车）
4. `git init` + 生成 `.gitignore` / `README.md` / `LICENSE`
5. 跑脱敏扫描，命中项让你逐条确认
6. 提交、建仓、推送
7. 用 GitHub API 核对提交是否归属到你

看到下面这行就是成功：

```
仓库: https://github.com/<你>/<项目名>
OK：提交已归属到你
```

然后发第一个版本：

```bash
bash <skill目录>/scripts/publish.sh --tag v0.1.0 --notes CHANGELOG.md
```

## 路线 B：手动

```bash
# 1. 身份
git config --global user.name "你的用户名"
git config --global user.email "你的数字ID+用户名@users.noreply.github.com"

# 2. 登录
gh auth login --web

# 3. 发布
cd 你的项目
git init -b main
printf ".DS_Store\nnode_modules/\n.env\n" > .gitignore
git add -A
git commit -m "feat: 初始提交"
gh repo create <你的用户名>/<项目名> --public --source . --remote origin --push
```

数字 ID：`curl -s https://api.github.com/users/<用户名> | grep '"id"'`

## 发布前先自检

```bash
bash scripts/doctor.sh .
```

会检查：git/gh 版本、是否登录、身份邮箱、当前分支、远端提交数、`.env`、>50MB 大文件、脱敏扫描。

输出全部 `PASS` 就可以发；`FAIL` 必须处理，`WARN` 看一眼是否可接受。

## 补齐门面

- `README.md`：一句话是什么、怎么装、怎么用、一张截图
- `LICENSE`：个人项目用 MIT 最省事
- `CHANGELOG.md`：第一个版本就开始记

模板在 `templates/`，直接复制改。

## 每次改动之后

```bash
git add -A
git commit -m "fix: 修了某个问题"
git push
```

## 给开源项目提 PR

1. 项目页点 Fork
2. `gh repo fork <原作者>/<项目> --clone`
3. 新建分支改代码，提交并 push
4. 项目页出现 Compare & pull request，写清问题与验证方式
5. 按 review 意见追加提交

## 卡住了

- 先看 `references/faq.md`（27 个高频问题）
- 再看 `references/troubleshooting.md`（报错对照表）
- 仍然不行：把完整报错发给 agent，不要自己连续试 `--force`

## 三条保命规则

- 提交前 `git status` 看一眼，别把密钥和垃圾文件带上
- 不确定的命令先 `--help`，不要直接 `--force`
- 出错不可怕：GitHub 保留历史，按 troubleshooting 恢复
