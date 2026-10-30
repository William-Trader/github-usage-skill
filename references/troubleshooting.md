# 故障排查

## 1. 贡献图没有我 / 提交记到别人名下

判断：

```bash
git log -1 --format='%an <%ae>'
gh api repos/<owner>/<repo>/commits --jq '.[0].author.login'
```

- `author.login` 为 `null` 或不是本人 → 历史里的邮箱不对
- 修法：`scripts/fix-authorship.sh <repo> "<坏邮箱1>,<坏邮箱2>"`
- 修完必须 `gh api` 复核，不能只看 `git log`

## 2. 强推之后远端历史变短了

原因：本地分支只含部分历史（浅克隆/只 checkout 了少数提交），`--force` 把远端覆盖成短历史。

恢复顺序：

1. `git reflog show origin/<branch>` 找 `filter-branch: rewrite` 或上一个远端提交
2. `git fsck --no-reflogs --dangling | grep commit` 找悬空提交
3. 用找到的提交直接推：`git push --force origin <sha>:refs/heads/<branch>`
4. 核对 `git rev-list --count origin/<branch>` 与事故前一致

预防：推之前比较 `git rev-list --count HEAD` 与 `git rev-list --count origin/<branch>`；优先 `--force-with-lease`。

## 3. `git reset --hard` 冲掉未提交修改

1. `git stash list` 看有没有自动/手动 stash
2. `git fsck --unreachable --no-reflogs` 找悬空 blob/commit
3. 从 stash commit 恢复：`git checkout <stash-sha> -- <file>`
4. 以后先 `git stash push -m "wip"` 再动历史

## 4. 推送被拒绝

| 报错 | 原因 | 处理 |
|---|---|---|
| `non-fast-forward` | 远端有你没有的提交 | 先 `git pull --rebase`，不要直接 force |
| `protected branch` | 分支保护 | 走 PR 或临时解除保护 |
| `file exceeds 100MB` | 大文件进历史 | 用 release asset；已提交则 `git filter-repo` 清理后重写 |
| `GH013 repository rule violations` | 组织规则/密钥扫描 | 按提示移除敏感内容后重试 |

## 5. 密钥被提交了

1. 立即在厂商侧 revoke/轮换，历史清理不能替代轮换
2. 从工作区删除并加入 `.gitignore`
3. 历史清理：`git filter-repo --path .env --invert-paths`
4. 强推并通知协作者重新克隆

## 6. 多个身份混用

```bash
git config --show-origin --get-all user.email
git log --format='%ae' | sort | uniq -c
```

出现多个邮箱时，先统一配置，再按第 1 节重写历史；不要只改最近一条提交。
