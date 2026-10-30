# 新手常见问题（直给答案）

## 账号与登录

**Q1：gh 是什么？必须装吗？**
GitHub 官方命令行工具。装了就少点十几次网页；不装也能用网页完成，但本 skill 的命令都基于 gh。

**Q2：`gh auth login` 选哪个？**
选 GitHub.com → HTTPS → Login with a web browser，复制一次性码到浏览器即可。

**Q3：我没有 SSH key，能推送吗？**
能。HTTPS + gh 登录足够；SSH 只是可选。

**Q4：手机能发布吗？**
能，用 GitHub 网页上传文件；但要版本管理还是电脑上做。

## 仓库与提交

**Q5：仓库（Repository）到底是什么？**
代码 + 全部历史 + Issue/PR/Actions/Projects 的协作空间。不是文件夹，是一个带时间机器的项目空间。

**Q6：clone、fork、下载 ZIP 有什么区别？**
clone 是本地副本（能推送）；fork 是你账号下的服务器副本（用来给别人的仓库提 PR）；ZIP 只是快照，没有历史。

**Q7：branch 是什么，必须用吗？**
指向一条提交线的指针。一个人小项目可以直接在 `main` 提交；多人或要评审时开 `feat/xxx` 分支。

**Q8：commit 写什么？**
`feat: 新增导出` / `fix: 修复上传超时`。一次只做一件事，将来出问题好回滚。

**Q9：`git pull` 和 `git fetch` 区别？**
fetch 只下载，不动工作区；pull = fetch + 合并。冲突时先 fetch 看清再决定。

**Q10：为什么推送被拒绝（non-fast-forward）？**
远端有你没有的提交（常见于网页上改过 README）。先 `git pull --rebase`，不要直接 `--force`。

## 归属与贡献

**Q11：提交了但贡献图没有我？**
看邮箱：`git log -1 --format='%ae'`。必须是 `<数字ID>+<用户名>@users.noreply.github.com`，名字写对没用。

**Q12：`william@users.noreply.github.com` 有什么问题？**
GitHub 上真的存在 `william` 账号，提交会算到那个人头上。

**Q13：怎么改历史里的错误作者？**
`bash scripts/fix-authorship.sh <repo> "<坏邮箱>"`，脚本会先比对提交数再推送。

**Q14：能改别人仓库的提交作者吗？**
不能，也不应该。只能改自己有写权限的仓库；fork 的上游历史不要动。

**Q15：怎么给开源项目贡献？**
fork → 新分支 → 小改动 → 提交 → push → 网页会出现 Compare & pull request → 填清楚问题与验证。

## Issue / PR / Projects

**Q16：Issue 和 PR 区别？**
Issue 是「要做什么/哪里坏了」；PR 是「我改好了，请求合并」。

**Q17：Projects 是什么，必须用吗？**
挂在仓库上的计划视图（表格/看板/路线图），数据来自 Issue 与 PR。个人小项目可以不用。

**Q18：PR 里 `closes #12` 有什么用？**
PR 合并时自动关闭第 12 号 Issue。

**Q19：Draft PR 是什么？**
还没改完、先让人看方向的 PR，不会被合并。

**Q20：Squash / Merge / Rebase 选哪个？**
个人项目用 Squash（历史干净）；要保留每次提交用 Merge；团队要求线性历史用 Rebase。

## 发版

**Q21：tag 和 release 区别？**
tag 是代码上的书签；release 是带说明和安装包的发行页。

**Q22：版本号怎么定？**
修 bug 升最后一位（1.0.1），加功能升中间（1.1.0），破坏兼容升第一位（2.0.0）。

**Q23：安装包放哪？**
release 的 assets，不要提交进 git（大文件会永久留在历史里）。

**Q24：发错了怎么办？**
发新版本修；必须删就 `gh release delete vX --yes` 后重发，并说明原因。不要悄悄改已发布的 tag。

## 安全

**Q25：密钥不小心提交了？**
立刻去厂商后台 revoke/轮换，再清理历史。清理历史不能替代轮换。

**Q26：仓库要公开，先检查什么？**
`bash scripts/preflight-scan.sh .`：密钥、IP、绝对路径、真实身份、`.env`、大文件。

**Q27：`.env.example` 能提交吗？**
能，只放占位符，不放真实值。
