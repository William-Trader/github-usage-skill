#!/usr/bin/env node
/**
 * server-shot.mjs — 给线上页面拍一张「可当证据」的截图，并收集前端错误。
 *
 * 零依赖：用本机已装的 Chrome/Edge/Chromium 的 DevTools Protocol。
 * 需要 Node >= 22（内置 WebSocket）。
 *
 * 用法：
 *   node scripts/server-shot.mjs --url http://203.0.113.10:3000/ --out evidence/
 *   node scripts/server-shot.mjs --url https://example.com --out evidence/ --full
 *   node scripts/server-shot.mjs --url https://example.com --out evidence/ --mobile
 *
 * 输出：
 *   evidence/<host>-<时间>-desktop.png
 *   evidence/<host>-<时间>-mobile.png   （--mobile 或 --both）
 *   evidence/<host>-<时间>.json         （标题、状态、控制台错误、失败请求）
 */

import { spawn } from "node:child_process";
import { mkdtemp, mkdir, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, basename } from "node:path";
import net from "node:net";

const args = Object.fromEntries(
  process.argv.slice(2).reduce((acc, cur, i, arr) => {
    if (cur.startsWith("--")) {
      const key = cur.slice(2);
      const next = arr[i + 1];
      acc.push([key, next && !next.startsWith("--") ? next : true]);
    }
    return acc;
  }, [])
);

const url = args.url;
const outDir = args.out || "evidence";
const waitMs = Number(args.wait || 1800);
const fullPage = Boolean(args.full);
const both = Boolean(args.both);
const mobileOnly = Boolean(args.mobile);
const timeoutMs = Number(args.timeout || 30000);

if (!url) {
  console.error("缺少 --url\n用法: node scripts/server-shot.mjs --url <URL> --out <目录> [--full] [--mobile|--both]");
  process.exit(2);
}

const CANDIDATES = [
  process.env.CHROME_BIN,
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
  "/Applications/Chromium.app/Contents/MacOS/Chromium",
  "/usr/bin/google-chrome",
  "/usr/bin/chromium",
  "/usr/bin/chromium-browser",
].filter(Boolean);

function exists(path) {
  return import("node:fs").then(({ existsSync }) => existsSync(path));
}

async function findChrome() {
  for (const p of CANDIDATES) {
    if (await exists(p)) return p;
  }
  throw new Error("找不到 Chrome/Edge/Chromium，请设置 CHROME_BIN 指向可执行文件");
}

function freePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.once("error", reject);
    srv.listen(0, "127.0.0.1", () => {
      const port = srv.address().port;
      srv.close(() => resolve(port));
    });
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitForJson(port, timeoutMsLocal) {
  const deadline = Date.now() + timeoutMsLocal;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(`http://127.0.0.1:${port}/json/version`);
      if (res.ok) return res.json();
    } catch {}
    await sleep(200);
  }
  throw new Error("浏览器调试端口未就绪");
}

class CDP {
  constructor(wsUrl) {
    this.ws = new WebSocket(wsUrl);
    this.id = 0;
    this.pending = new Map();
    this.handlers = new Map();
    this.ready = new Promise((resolve, reject) => {
      this.ws.addEventListener("open", () => resolve());
      this.ws.addEventListener("error", (e) => reject(new Error("CDP 连接失败")));
    });
    this.ws.addEventListener("message", (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id && this.pending.has(msg.id)) {
        const { resolve, reject, timer } = this.pending.get(msg.id);
        clearTimeout(timer);
        this.pending.delete(msg.id);
        msg.error ? reject(new Error(msg.error.message)) : resolve(msg.result);
        return;
      }
      const list = this.handlers.get(msg.method);
      if (list) for (const fn of list) fn(msg.params);
    });
  }
  on(method, fn) {
    if (!this.handlers.has(method)) this.handlers.set(method, []);
    this.handlers.get(method).push(fn);
  }
  send(method, params = {}, timeout = 15000) {
    const id = ++this.id;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`${method} 超时`));
      }, timeout);
      this.pending.set(id, { resolve, reject, timer });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }
  close() {
    try { this.ws.close(); } catch {}
  }
}

async function capture({ chromePath, port, pageUrl, out, viewport, mobile, full, wait }) {
  // 新建 target（新版 Chrome 需要 PUT）
  let target;
  for (const method of ["PUT", "GET"]) {
    const res = await fetch(`http://127.0.0.1:${port}/json/new?about:blank`, { method });
    if (res.ok) { target = await res.json(); break; }
  }
  if (!target) throw new Error("无法创建浏览器标签页");

  const cdp = new CDP(target.webSocketDebuggerUrl);
  await cdp.ready;

  const consoleErrors = [];
  const exceptions = [];
  const failedRequests = [];
  const httpErrors = [];

  cdp.on("Runtime.consoleAPICalled", (p) => {
    if (p.type === "error") {
      consoleErrors.push(p.args.map((a) => a.value ?? a.description ?? "").join(" ").slice(0, 300));
    }
  });
  cdp.on("Runtime.exceptionThrown", (p) => {
    exceptions.push((p.exceptionDetails?.exception?.description || p.exceptionDetails?.text || "exception").slice(0, 300));
  });
  cdp.on("Network.loadingFailed", (p) => {
    if (!p.canceled) failedRequests.push(`${p.type || "?"}: ${p.errorText}`);
  });
  cdp.on("Network.responseReceived", (p) => {
    if (p.response?.status >= 400) {
      httpErrors.push(`${p.response.status} ${p.response.url.slice(0, 200)}`);
    }
  });

  await cdp.send("Page.enable");
  await cdp.send("Runtime.enable");
  await cdp.send("Network.enable");
  await cdp.send("Emulation.setDeviceMetricsOverride", {
    width: viewport.width,
    height: viewport.height,
    deviceScaleFactor: mobile ? 2 : 1,
    mobile,
  });
  if (mobile) {
    await cdp.send("Network.setUserAgentOverride", {
      userAgent:
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
    });
  }

  const loaded = new Promise((resolve) => {
    cdp.on("Page.loadEventFired", () => resolve(true));
    setTimeout(() => resolve(false), timeoutMs);
  });

  const nav = await cdp.send("Page.navigate", { url: pageUrl }, timeoutMs);
  if (nav.errorText) throw new Error(`导航失败: ${nav.errorText}`);

  await loaded;
  await sleep(wait);

  const titleRes = await cdp.send("Runtime.evaluate", {
    expression: "document.title",
    returnByValue: true,
  });
  const title = titleRes.result?.value || "";

  const bodyLenRes = await cdp.send("Runtime.evaluate", {
    expression: "document.body ? document.body.innerText.trim().length : 0",
    returnByValue: true,
  });
  const bodyLength = bodyLenRes.result?.value || 0;

  let shotHeight = viewport.height;
  if (full) {
    const metrics = await cdp.send("Page.getLayoutMetrics");
    const content = metrics.cssContentSize || metrics.contentSize;
    shotHeight = Math.min(Math.ceil(content.height), 6000);
    await cdp.send("Emulation.setDeviceMetricsOverride", {
      width: viewport.width,
      height: shotHeight,
      deviceScaleFactor: mobile ? 2 : 1,
      mobile,
    });
    await sleep(300);
  }

  const shot = await cdp.send(
    "Page.captureScreenshot",
    { format: "png", captureBeyondViewport: full, fromSurface: true },
    30000
  );

  await writeFile(out, Buffer.from(shot.data, "base64"));
  cdp.close();
  try { await fetch(`http://127.0.0.1:${port}/json/close/${target.id}`); } catch {}

  return {
    url: pageUrl,
    title,
    bodyLength,
    viewport: `${viewport.width}x${shotHeight}`,
    mobile,
    screenshot: out,
    consoleErrors,
    exceptions,
    failedRequests,
    httpErrors,
  };
}

(async () => {
  const started = Date.now();
  const chromePath = await findChrome();
  const port = await freePort();
  const profileDir = await mkdtemp(join(tmpdir(), "server-shot-"));
  await mkdir(outDir, { recursive: true });

  const chrome = spawn(
    chromePath,
    [
      "--headless=new",
      "--disable-gpu",
      "--hide-scrollbars",
      "--no-first-run",
      "--no-default-browser-check",
      "--disable-extensions",
      `--remote-debugging-port=${port}`,
      `--user-data-dir=${profileDir}`,
      "about:blank",
    ],
    { stdio: "ignore" }
  );

  const stamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
  const host = (() => { try { return new URL(url).host.replace(/[^a-zA-Z0-9.-]/g, "_"); } catch { return "page"; } })();
  const results = [];

  try {
    await waitForJson(port, 15000);
    const desktopViewport = { width: 1440, height: 900 };
    const mobileViewport = { width: 390, height: 844 };

    if (!mobileOnly) {
      results.push(
        await capture({
          chromePath, port, pageUrl: url,
          out: join(outDir, `${host}-${stamp}-desktop.png`),
          viewport: desktopViewport, mobile: false, full: fullPage, wait: waitMs,
        })
      );
    }
    if (mobileOnly || both) {
      results.push(
        await capture({
          chromePath, port, pageUrl: url,
          out: join(outDir, `${host}-${stamp}-mobile.png`),
          viewport: mobileViewport, mobile: true, full: fullPage, wait: waitMs,
        })
      );
    }

    const report = { url, capturedAt: new Date().toISOString(), durationMs: Date.now() - started, results };
    const reportPath = join(outDir, `${host}-${stamp}.json`);
    await writeFile(reportPath, JSON.stringify(report, null, 2));

    for (const r of results) {
      console.log(`[${r.mobile ? "mobile" : "desktop"}] ${r.title || "(无标题)"} -> ${r.screenshot}`);
      if (r.exceptions.length) console.log(`  异常 ${r.exceptions.length} 条`);
      if (r.httpErrors.length) console.log(`  HTTP 错误 ${r.httpErrors.length} 条`);
      if (r.failedRequests.length) console.log(`  请求失败 ${r.failedRequests.length} 条`);
      if (r.consoleErrors.length) console.log(`  控制台错误 ${r.consoleErrors.length} 条`);
    }
    console.log(`报告: ${reportPath}`);

    const bad =
      results.some((r) => r.exceptions.length || r.httpErrors.length) ||
      results.some((r) => r.bodyLength === 0);
    process.exitCode = bad ? 1 : 0;
  } finally {
    chrome.kill("SIGKILL");
    await rm(profileDir, { recursive: true, force: true }).catch(() => {});
  }
})().catch((err) => {
  console.error("截图失败:", err.message);
  process.exit(1);
});
