# 身份与认证

## 1. 三种 GitHub 提交身份，只有一种是安全的

| 写法 | GitHub 归属 | 结论 |
|---|---|---|
| `331161833+William-Trader@users.noreply.github.com` | 正确（数字 ID + 用户名） | 唯一推荐 |
| `William-Trader@users.noreply.github.com` | 通常正确（按用户名匹配） | 可用，但改用户名后会失效 |
| `william@users.noreply.github.com` | **错误**：会落到 `william` 这个真实账号 | 绝对禁用 |
| `william@localhost` / `william@local` / `si@local` / `*@*.local` | 不归属任何人 | 必须修 |
| `12345678+someone@users.noreply.github.com` | 归属那个 ID 对应的人 | 从别处复制配置时最容易踩 |

规则：**名字写对没用，邮箱才决定归属。** 提交前用 `git log -1 --format='%an <%ae>'` 看一眼。

## 2. 检查与设置

```bash
git config --show-origin --get-all user.name
git config --show-origin --get-all user.email
git config --global user.name "William-Trader"
git config --global user.email "331161833+William-Trader@users.noreply.github.com"
```

仓库级配置会覆盖全局；`--show-origin` 能看出是哪一层在生效。

## 3. 认证方式

### gh CLI（推荐）

```bash
gh auth status
gh auth login --web
gh api user --jq .login
```

scopes 不足时：`gh auth refresh -s repo,workflow`。

### SSH（可选）

```bash
ssh-keygen -t ed25519 -C "331161833+William-Trader@users.noreply.github.com"
gh ssh-key add ~/.ssh/id_ed25519.pub --title "macbook"
ssh -T git@github.com
```

### PAT（不推荐，但 CI 需要）

- fine-grained token，只给目标仓库与最小权限；
- 存在 CI secret 或 600 文件，不写进仓库、不回显；
- 泄露后立即 revoke，再轮换。

## 4. 常见认证错误

| 现象 | 原因 | 处理 |
|---|---|---|
| `remote: Permission denied` | 当前 gh 账号无该仓库权限 | `gh auth status` 看账号；必要时 `gh auth switch` |
| `403 Resource not accessible by personal access token` | token scope 不足 | fine-grained token 勾选 Contents/PR 权限 |
| `Support for password authentication was removed` | 用了账号密码 | 改用 gh 或 SSH |
| 推送成功但贡献图没有 | 邮箱不是本人 noreply | 按第 1 节改正并重写历史 |
