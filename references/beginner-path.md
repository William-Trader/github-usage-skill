# 0 基础第一次发布

目标：30 分钟内把本地项目变成 GitHub 上可访问的仓库，并打上第一个版本。

## 准备

1. 注册 GitHub 账号，记住用户名
2. 安装 gh：macOS `brew install gh`，Windows `winget install GitHub.cli`
3. `gh auth login --web`，浏览器授权
4. 设置身份：

```bash
git config --global user.name "你的用户名"
git config --global user.email "你的数字ID+用户名@users.noreply.github.com"
```

数字 ID 在 `https://api.github.com/users/<用户名>` 的 `id` 字段。

## 发布

```bash
cd 你的项目
git init -b main
printf ".DS_Store\nnode_modules/\n.env\n" > .gitignore
git add -A
git commit -m "feat: 初始提交"
gh repo create <你的用户名>/<项目名> --public --source . --remote origin --push
```

看到 `https://github.com/<你>/<项目名>` 即成功。

## 补齐门面

- README：一句话是什么、怎么装、怎么用、截图
- LICENSE：个人项目用 MIT 最省事
- 第一个 release：

```bash
git tag -a v0.1.0 -m "v0.1.0"
git push origin v0.1.0
gh release create v0.1.0 --title "v0.1.0" --notes "第一个可用版本"
```

## 之后每次改动

```bash
git add -A
git commit -m "fix: 修了某个问题"
git push
```

## 给开源项目提 PR

1. 在项目页点 Fork
2. `gh repo fork <原作者>/<项目> --clone`
3. 新建分支改代码，提交并 push
4. 项目页会出现 Compare & pull request，填写问题与验证方式
5. 等维护者 review，按意见追加提交

## 三条保命规则

- 提交前 `git status` 看一遍，别把密钥和垃圾文件带上
- 不确定的命令先 `--help` 或问 agent，别直接 `--force`
- 出错不可怕：GitHub 保留历史，按 troubleshooting 里的恢复步骤处理
