# 打包与发版

## 1. 版本号

语义化版本 `MAJOR.MINOR.PATCH`：

- 修 bug、文档、兼容性小改动 → PATCH
- 新增向后兼容能力 → MINOR
- 破坏兼容的改动 → MAJOR

所有版本号必须在同一提交里同步：`package.json` / `pyproject.toml` / `Cargo.toml` / 版本常量 / README 标题。

## 2. tag 与 release

```bash
git tag -a v1.2.3 -m "v1.2.3"
git push origin main
git push origin v1.2.3
gh release create v1.2.3 ./dist/app.zip \
  --title "v1.2.3" \
  --notes-file CHANGELOG.md
```

- annotated tag（`-a`）才带作者与时间；lightweight tag 不适合做发行标记。
- release notes 写「变化 / 修复 / 破坏性变更 / 升级方法」。
- 产物上传到 release，不提交进 git 历史。

## 3. 各类型项目怎么打包

### Node / 零依赖服务

- 源码直发：`package.json` 的 `bin` 或 `scripts.start`
- 产物：`npm pack` 生成 tgz，或打 `dist/app.zip`
- 明确最低 Node 版本（`engines`）

### 单文件 HTML / 前端

- 直接发布 `index.html` + 静态资源目录
- GitHub Pages：Settings → Pages → Deploy from branch
- release 里放一份可离线打开的 zip

### Python

```bash
python -m build            # dist/*.whl + *.tar.gz
gh release create vX dist/*
```

### Electron / 桌面

- macOS 与 Windows 分别打包，产物带平台与架构
- macOS 未签名时在 README 写明 `xattr -dr com.apple.quarantine` 的处理方式
- 校验和：`shasum -a 256 dist/* > SHA256SUMS.txt` 一并上传

## 4. 发布前检查

- 测试通过，版本号已同步
- `git status` 干净，tag 指向发布提交
- 产物能在干净机器上跑通（至少换目录/换用户）
- release 描述含安装与升级步骤
- 敏感信息扫描通过

## 5. 回滚

- 小问题：发新 PATCH，别移动已发布的 tag
- 严重问题：`gh release delete vX --yes` 后重发，并在 notes 说明原因
- 代码回滚用 `git revert`，不要改写已发布历史
