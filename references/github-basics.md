# GitHub 基础常识

一页看懂 GitHub 的每个按钮是干什么的。新手先读这一篇，再去看具体操作。

## 1. 账号：个人号与组织

| 概念 | 说明 |
|---|---|
| 个人账号 | `github.com/<用户名>`，所有个人仓库的默认归属 |
| 组织 Organization | 团队共享的账号，仓库归组织；成员按角色授权 |
| Profile README | 建一个与用户名同名的仓库，它的 README 会显示在个人主页 |
| Follow / Followers | 关注人，类似社交；不影响仓库权限 |
| Star | 收藏 + 表态，出现在你的 Stars 列表；不等于 fork |
| Watch | 订阅通知：Issues / PR / Releases 可选 |

## 2. 仓库 Repository

仓库 = 代码 + 历史 + 协作设施。一个仓库包含：

| 页面 | 作用 |
|---|---|
| Code | 文件、分支切换、提交历史、克隆地址 |
| Issues | 任务、bug、需求，支持标签/指派/里程碑 |
| Pull requests | 变更评审与合并 |
| Actions | CI/CD 流水线（测试、构建、发布） |
| Projects | 跨 issue/PR 的看板与路线图 |
| Wiki | 项目文档（可关闭） |
| Security | 依赖漏洞、密钥扫描、告警 |
| Insights | 流量、提交活跃度、依赖图 |
| Settings | 可见性、协作者、分支保护、Webhooks、删除 |

关键区别：

- **Clone**：把仓库复制到本地，保留关联，能 push（有权限时）
- **Fork**：在你自己账号下复制一份，用于给别人的仓库提 PR
- **Template**：把仓库当模板新建一个全新历史的仓库
- **Download ZIP**：只下当前快照，没有 git 历史

可见性：Public（所有人可见）/ Private（仅授权者）/ Internal（企业内）。

## 3. 代码概念

| 概念 | 一句话 |
|---|---|
| Commit | 一次快照 + 说明 + 作者/时间，有唯一 SHA |
| Branch 分支 | 指向某条提交线的可移动指针；`main` 是默认主线 |
| Tag 标签 | 指向某个提交的固定名字，用于发版（`v1.2.0`） |
| Remote | 远端地址；`origin` 是你 clone/fork 来的仓库，`upstream` 常指原仓库 |
| HEAD | 当前所在提交 |
| Merge | 把两条分支合并，可能产生 merge commit |
| Rebase | 把提交“搬”到另一条基线，历史更线性，但会改写 SHA |
| Conflict | 同一处被两边改动，需要人工决定保留哪边 |

## 4. 分支怎么用

- `main` 永远保持可运行
- 每个任务开短分支：`feat/login`、`fix/upload-timeout`
- 完成后开 PR 合并，合并即删除分支
- 保护 `main`：Settings → Branches/Rulesets，禁止直接 push、要求 PR 与检查通过

常用命令：

```bash
git switch -c feat/login      # 新建并切换
git switch main               # 回主线
git branch -a                 # 本地+远端分支
git merge feat/login          # 合并
git rebase main               # 变基（改写当前分支历史）
```

## 5. Issues：把事说清楚

一个合格 issue 包含：现象、复现步骤、期望结果、实际结果、环境版本。

- 标签：`bug` / `enhancement` / `question` / `documentation` / `good first issue` / `help wanted`
- 指派 Assignee：谁负责
- 里程碑 Milestone：归到哪个版本
- 任务列表：`- [ ] 子任务`
- 关联：正文写 `closes #12`，PR 合并时自动关闭 issue

## 6. Pull Request：变更评审

流程：分支 → 提交 → push → 开 PR → 评审 → 检查通过 → 合并。

| 概念 | 说明 |
|---|---|
| Draft PR | 未完成的 PR，先讨论不合并 |
| Review | Approve / Request changes / Comment |
| Checks | CI 结果，红了不能合并（受保护分支） |
| Merge commit | 保留分支历史，生成合并提交 |
| Squash and merge | 多条提交压成一条，历史干净（最常用） |
| Rebase and merge | 逐条搬到主线，线性历史 |
| Fork PR | 从 fork 提给上游；维护者可用 `gh pr checkout <编号>` 本地验证 |

冲突处理：本地 `git pull --rebase` 后手工解决，`git add` 标记已解决，继续 rebase。

## 7. Projects：给项目做计划

GitHub Projects 是挂在仓库或组织下的**计划视图**，不是代码。

- 数据来源：仓库里的 Issues 与 PR
- 三种视图：Table（表格）、Board（看板，按状态分列）、Roadmap（时间线）
- 自定义字段：Status（Todo/In Progress/Done）、Priority、Size、迭代、日期
- 自动化：issue 打开 → 自动加入；PR 合并 → 自动置 Done
- 用法：个人项目当 TODO 看板；团队项目当迭代计划

入口：仓库顶部 Projects → New project。它不是必需功能，小项目可以只用 Issues。

## 8. Discussions：社区讨论

适合“没有明确 bug 的开放讨论”：用法提问、想法投票、公告、展示作品。

- 分类 Categories（Announcements / Q&A / Ideas / Show and tell）
- 可标记答案，形成可检索的问答库
- 与 Issues 的区别：Issue 是待办事项，Discussion 是对话

## 9. Actions：自动化

`.github/workflows/*.yml` 定义流水线：

```yaml
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm test
```

- Secrets 存在 Settings → Secrets and variables → Actions，不在仓库里
- 常见用途：跑测试、构建产物、自动发 release、定时任务
- 公开仓库的 Actions 有免费额度；私有仓库按分钟计费

## 10. Releases 与 Packages

- Release：基于 tag 的发行说明 + 可下载产物（zip、dmg、exe）
- Packages：包 registry（npm、容器镜像、Maven 等）
- 发版 = tag + release notes + 产物；不要只打 tag 不写说明

## 11. 社区协作的标配文件

| 文件 | 作用 |
|---|---|
| `README.md` | 项目门面：是什么、怎么装、怎么用 |
| `LICENSE` | 使用许可；没有 = 保留所有权利 |
| `CONTRIBUTING.md` | 怎么贡献：分支、提交规范、测试要求 |
| `CODE_OF_CONDUCT.md` | 行为准则 |
| `.github/ISSUE_TEMPLATE/*.yml` | Issue 表单 |
| `.github/pull_request_template.md` | PR 检查清单 |
| `SECURITY.md` | 漏洞怎么私密上报 |
| `CHANGELOG.md` | 版本变化 |

社区标签约定：`good first issue`（适合新人）、`help wanted`（求协助）、`bug`、`enhancement`、`question`、`wontfix`、`duplicate`。

## 12. 权限与安全

| 角色 | 能做什么 |
|---|---|
| Read | 看代码、开 issue |
| Triage | 管理 issue/PR 标签与指派 |
| Write | push 代码、合并 PR |
| Maintain | 管理仓库设置（不含删除/转移） |
| Admin | 全部，包括删除与转移 |

安全清单：

- 账号开 2FA
- SSH key 或 gh 登录，别用账号密码
- PAT 用 fine-grained，最小权限、设过期
- 开启 secret scanning 与 Dependabot alerts
- 分支保护 + 必需检查，防止误推

## 13. 常用 Markdown

```markdown
**粗体** *斜体* `代码` [链接](https://example.com)
- [ ] 任务
- [x] 已完成
@用户名  #12 引用 issue/PR
> 引用
```

代码块用三个反引号加语言名；表格用 `|` 分隔；图片直接拖进编辑框。

## 14. 搜索与发现

- `repo:owner/name keyword`：仓库内搜
- `is:issue is:open label:bug`：筛选 issue
- `language:python stars:>100`：找项目
- Topics：仓库设置里的标签，决定别人怎么发现你

## 15. 最容易混淆的几组

| 容易混 | 区别 |
|---|---|
| Star vs Fork | Star 是收藏/表态；Fork 是复制一份可改的仓库 |
| Watch vs Star | Watch 收通知；Star 不进通知 |
| Clone vs Fork | Clone 是本地副本；Fork 是服务器上的副本 |
| Issue vs Discussion | Issue 是待办；Discussion 是对话 |
| Tag vs Branch | Tag 固定不动；Branch 随提交前进 |
| Merge vs Rebase | Merge 保留分叉；Rebase 改写历史 |
| Project vs Repository | Project 是计划视图；Repository 是代码与协作本体 |
