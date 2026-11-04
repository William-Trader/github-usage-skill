# 上线验收：功能检测 + 前端截图

「接口 200」不等于「用户能用」。验收要三层证据，缺一层都不算完成：

| 层 | 证据 | 工具 |
|---|---|---|
| 服务层 | `systemctl is-active`、端口、磁盘、内存、失败单元 | `scripts/server-doctor.sh` |
| 接口层 | HTTP 状态、耗时、标题、静态资源、关键 API、TLS | `scripts/server-verify.sh` |
| 界面层 | 桌面 + 移动截图、控制台错误、空白页/布局溢出 | `scripts/server-shot.mjs` |

**有前端就必须有截图。** 没有截图的「已上线」等于没验收。

## 1. 一条命令跑完服务 + 接口

```bash
bash scripts/server-verify.sh \
  --url https://example.com \
  --api /health,/api/status \
  --shot evidence/ \
  --report evidence/report.md
```

检查项与判读：

| 检查 | 通过标准 | 不通过时先看 |
|---|---|---|
| DNS | 解析到预期 IP | 域名解析、A 记录 |
| TCP | 端口可连接 | 安全组、主机防火墙、服务监听 |
| HTTP | 200（或约定状态） | 502 → 后端；404 → 路由；000 → 网络/监听 |
| 耗时 | < 3s（首字节+下载） | 主机负载、慢查询、外网依赖 |
| 标题 | 非空 | 空壳、错误页、SPA 未挂载 |
| 响应体 | > 200B | 空页面、被拦截 |
| 压缩 | gzip/br | 反代未开压缩 |
| 安全头 | 按业务要求 | 反代配置 |
| 静态资源 | 同源 css/js 全 200 | 构建产物缺失、路径写错 |
| API | 200 且 JSON 可解析 | 鉴权、路径、后端异常 |
| TLS | 剩余 > 14 天 | 证书续期 |

## 2. 前端截图（桌面 + 移动）

```bash
node scripts/server-shot.mjs --url https://example.com --out evidence/ --both --full
```

输出三样东西：

- `evidence/<host>-<时间>-desktop.png`（1440×900，可全页）
- `evidence/<host>-<时间>-mobile.png`（390×844，移动 UA）
- `evidence/<host>-<时间>.json`（标题、正文长度、控制台错误、HTTP 错误、失败请求）

截图脚本用**本机** Chrome/Edge/Chromium 的 DevTools Protocol，服务器上不用装浏览器。

判读：

- 截图必须是**真实渲染**：有导航、有数据、有图表；纯背景色 = 空白失败。
- JSON 里 `exceptions`、`httpErrors`、`failedRequests` 任一非空，必须查清再宣布完成。
- 移动截图出现内容溢出/按钮被挤出屏幕，算 UI 缺陷，不是「能用」。

## 3. 前端专项检查

除了脚本自动收集的，再人工确认这五项：

1. **首屏有内容**：不是骨架屏一直转、不是「加载中」卡死。
2. **关键数据非空**：KPI/列表/图表有真实数字，不是 `--` 或 0 占位。
3. **控制台干净**：没有红色报错、没有 404 资源、没有 CORS/Mixed Content。
4. **移动端不横向溢出**：页面宽度不超过视口；表格可滚动但页面不抖。
5. **交互可用**：至少点一次主按钮/切一次标签，确认不是静态图。

需要登录才能看的页面：

- 用测试账号，**不要截图含个人隐私、密钥、订单的页面**。
- 截图前遮掉敏感字段，或只截局部。
- 凭据不进截图、不进报告、不进 Git。

## 4. 功能检测（API / 业务）

```bash
# 单个接口
curl -s -o /tmp/api.json -w '%{http_code} %{time_total}\n' https://example.com/api/health
python3 -c 'import json;print(json.load(open("/tmp/api.json")))'
```

- GET 为主；**不要在验收里做写操作**（下单、支付、删除）。
- 需要写操作验证时，用测试环境或明确的测试数据，并先征得用户同意。
- 返回 200 但字段为空，等于没通过；要断言关键字段存在且非空。

## 5. 常见失败对照

| 现象 | 常见原因 | 处理 |
|---|---|---|
| 截图全黑/全白 | 页面没渲染，JS 报错 | 看 JSON 的 `exceptions` |
| 只有导航没有内容 | 接口失败，前端空态 | 看 `httpErrors` 与 Network |
| 资源 404 | 构建产物没上传/路径变了 | 重新构建并同步 `dist/` |
| 图表空白 | 数据接口失败或 canvas 未初始化 | 先修接口，再看控制台 |
| 移动端错位 | 固定宽度、未加 viewport | 改 CSS，`<meta name="viewport">` |
| 样式全丢 | 反代改了路径，静态资源 404 | 检查 `base`/反代 `location` |
| 混合内容被拦 | HTTPS 页面请求 HTTP 接口 | 接口也上 HTTPS |

## 6. 证据怎么留

```
evidence/
├── 2026-11-04T12-30-59-desktop.png
├── 2026-11-04T12-30-59-mobile.png
├── 2026-11-04T12-30-59.json
└── report.md
```

- 目录按日期/版本归档，不进公开仓库（截图可能含业务数据）。
- 交付说明里写：访问地址、截图路径、验收数字、FAIL/WARN 数。
- 报告模板：`templates/verification-report.template.md`。

## 7. 完成标准

- `server-verify.sh` 输出 `FAIL=0`
- 桌面与移动截图都是真实渲染，关键数据非空
- 控制台无异常、无资源 404
- 有前端时截图已归档；无前端时说明「本项目无前端」
- 报告里每个 PASS 都能对应一条命令或一张图
