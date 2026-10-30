# 仓库生命周期

## 1. 新建

```bash
git init -b main
git add -A
git commit -m "feat: 初始提交"
gh repo create <owner>/<name> --public --source . --remote origin --push
```

建库前确认三件事：owner、可见性、许可证。仓库名用小写连字符，避免空格与中文路径问题。

## 2. 首次整理

- `README.md`：一句话说明 + 安装 + 使用 + 截图/示例 + License
- `LICENSE`：没有许可证等于保留所有权利，别人不能合法使用
- `.gitignore`：语言模板起步，别提交 `.env`、`node_modules/`、`dist/`
- `CHANGELOG.md`：从第一个版本就记，发行时直接复用

## 3. 分支模型

- 小项目：`main` + 短命分支 `fix/xxx`、`feat/xxx`
- 合并前跑测试；用 PR 合并保留讨论记录
- 保护 `main`：Settings → Branches → 禁止直接 push、要求 PR

## 4. 协作者与转移

```bash
gh api repos/<owner>/<repo>/collaborators/<user> -X PUT -f permission=push
gh repo edit <owner>/<repo> --add-topic cli,ai
```

转移仓库：Settings → General → Danger Zone → Transfer。转移后旧链接会重定向，但 CI secret 不会跟过去。

## 5. 归档与删除

- 不再维护 → Archive（只读，保留历史）
- 真删除 → Settings → Delete，需输入仓库名确认；本地克隆不会消失

## 6. 多仓库统一维护

- 统一身份（见 identity-and-auth）
- 统一 `.gitignore` 与 `LICENSE`
- 定期跑 `scripts/audit-authorship.sh`，别等贡献图出问题
- 版本号与 CHANGELOG 同批更新
