# GitHub 使用 Skill

> 让 Agent 帮你把项目发布到 GitHub，而不会把提交记到别人名下。

一套面向 Agent 的 GitHub 操作手册：身份、认证、建仓、提交、打包、发版、作者归属修复、社区贡献。
人也能照着做——**0 基础可以完成第一次发布**。

---

## 它解决什么问题

| 问题 | 典型症状 | 本 skill 的做法 |
|---|---|---|
| **开发者错配** | 推送成功，但贡献图没有你，提交落在陌生人名下 | 强制使用 `331161833+William-Trader@users.noreply.github.com`；提供扫描与历史重写脚本 |
| **项目错配 / 历史截断** | `--force` 之后远端只剩 2 条提交，几十条历史消失 | 推送前比对本地与远端提交数，不满足直接中止；`--force-with-lease` |
| **认证混乱** | token 泄漏、403、SSH 未配置、把密钥粘进聊天 | gh keyring / 600 文件；扫描命令；最小权限流程 |
| **发版不规范** | 没有 tag、没有 release、产物靠网盘 | 语义化版本 + annotated tag + release asset + 校验和 |
| **小白无从下手** | 不知道从哪一步开始，怕搞坏 | `references/beginner-path.md` 一条命令一步走完 |

**最核心的一条**：Git 的归属看**邮箱**，不看名字。名字写成 `William-Trader` 但邮箱是 `william@users.noreply.github.com`，提交会记到 GitHub 上真实存在的 `william` 账号。

---

## 30 秒开始（人类）

```bash
# 1. 固定身份
git config --global user.name "你的用户名"
git config --global user.email "你的数字ID+用户名@users.noreply.github.com"

# 2. 登录
gh auth login --web

# 3. 发布
cd 你的项目 && git init -b main && git add -A && git commit -m "feat: 初始提交"
gh repo create <你的用户名>/<项目名> --public --source . --remote origin --push
```

数字 ID 查询：`curl -s https://api.github.com/users/<用户名> | grep '"id"'`

完整零基础路径见 [`references/beginner-path.md`](references/beginner-path.md)。

---

## Agent 怎么用

### 安装

把本仓库放进技能的搜索路径即可，例如：

```bash
git clone https://github.com/William-Trader/github-usage-skill.git \
  ~/.openclaw/skills/github-usage
```

OpenClaw 会读取 `SKILL.md` 的 `description` 自动匹配，不需要额外注册。

### 触发示例

- 「把这个项目发到 GitHub」
- 「为什么我的提交没算进贡献」
- 「把这个仓库的作者改成 William-Trader」
- 「给这个项目打 v1.2.0 并做 release」

### Agent 执行顺序

1. 固定身份 → 2. 查认证 → 3. 建仓/提交 → 4. 打包发版 → 5. 归属核对 → 6. 交付检查

`SKILL.md` 里每一步都写了命令和**完成标准**，Agent 不靠猜。

---

## 需求 → 用哪一步

| 你的需求 | 直接看 |
|---|---|
| GitHub 各页面/概念看不懂 | `references/github-basics.md` |
| 第一次发布项目 | `references/beginner-path.md` |
| 提交没算到我的贡献 | `scripts/audit-authorship.sh` → `scripts/fix-authorship.sh` |
| 强推后历史变短 | `references/troubleshooting.md` 第 2 节 |
| 打 tag / 做 release / 上传安装包 | `references/releases-and-packaging.md` |
| 403 / 推送被拒 / 密钥泄漏 | `references/troubleshooting.md` |
| 给开源项目提 PR | `SKILL.md` 第 6 节 |
| 多仓库统一身份 | `references/identity-and-auth.md` |

---

## 仓库结构

```
github-usage-skill/
├── SKILL.md                      # Agent 主流程（命令 + 完成标准）
├── README.md                     # 人看的入口
├── references/
│   ├── github-basics.md          # 仓库/分支/Issue/PR/Projects/社区常识
│   ├── identity-and-auth.md      # 身份矩阵、noreply 规则、认证排错
│   ├── repo-lifecycle.md         # 建仓、分支、保护、协作者、归档
│   ├── releases-and-packaging.md # 版本号、tag、release、各语言打包
│   ├── troubleshooting.md        # 错配、截断、拒绝推送、历史恢复
│   └── beginner-path.md          # 0 基础第一次发布
└── scripts/
    ├── audit-authorship.sh       # 批量扫描不可归属邮箱
    ├── fix-authorship.sh         # 重写 + 提交数校验 + 安全强推
    └── verify-remote-authors.sh  # 按 GitHub 账号逐仓核对
```

---

## GitHub 基础常识（新手先读）

| 你可能在问 | 一句话答案 |
|---|---|
| 仓库是什么 | 代码 + 历史 + Issue/PR/Actions/Projects 的协作载体 |
| branch 是什么 | 指向提交线的可移动指针，`main` 是主线，任务用短分支 |
| Issue 和 PR 区别 | Issue 是待办/bug；PR 是改好代码请求合并 |
| Projects 是什么 | 挂在仓库上的计划视图（表格/看板/路线图），数据来自 Issue 与 PR |
| Discussions 是什么 | 开放讨论区，问答/想法/公告，可标答案 |
| star / fork / watch | 收藏表态 / 复制仓库 / 订阅通知 |
| Actions 是什么 | CI/CD，自动跑测试、构建、发版 |
| 社区怎么参与 | fork → 分支 → 提交 → PR；先看 CONTRIBUTING 与 good first issue |

完整版：[`references/github-basics.md`](references/github-basics.md)

## 真实案例

一次对本机 17 个 GitHub 仓库的全量审计，发现 6 个仓库共 80 条提交记错人：

- `w1-quant-board` 43 条（`william@users.noreply.github.com` / `ubuntu@localhost.localdomain` / `w1@william.local` / QQ 邮箱）
- `w1-board` 30 条
- `codex-for-free` 3 条（`William <william@localhost>`）
- `cryptocurrency-market-live-briefing` 2 条（`SI <si@local>`）
- `Methodology-Of-William` 1 条（QQ 邮箱）
- `crazy-water-world` 1 条（`william@users.noreply.github.com`）

全部重写并推送后，用 GitHub API 逐仓核对：17/17 仓库 `bad=0`。

过程中两个仓库因为本地分支只有 2 条提交、远端有 60/3 条，首次强推导致远端历史被截断；最终从 `filter-branch` 的 rewritten ref 完整恢复。**这就是 `fix-authorship.sh` 里「提交数不一致直接中止」这条保护存在的原因。**

---

## 安全边界

- 只重写**你自己**的仓库；第三方 fork 的上游提交不动
- 强推前必须核对提交数，优先 `--force-with-lease`
- 动历史前先 stash；不要 `reset --hard` 掉未提交工作
- 密钥泄露先 revoke 再清理历史，清理不能替代轮换
- 本 skill 不保存任何凭据

---

## 贡献

Issue / PR 都欢迎。提交前请确认作者邮箱是你的 GitHub noreply 地址，否则贡献图不会记录。

## License

MIT
