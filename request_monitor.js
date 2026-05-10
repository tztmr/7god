#!/usr/bin/env node
const http = require("node:http");
const readline = require("node:readline");
const { URL } = require("node:url");

class RequestMonitor {
  constructor() {
    this.portStats = new Map();
    for (const port of [8081, 8082, 8083, 8084, 8085, 8086, 8087]) {
      this.portStats.set(port, {
        totalRequests: 0,
        requestsPerMinute: [],
        lastRequestTime: null,
        rpmLimit: 60,
      });
    }
  }

  recordRequest(port) {
    const stats = this.portStats.get(port);
    if (!stats) {
      return false;
    }
    const now = Date.now();
    stats.totalRequests += 1;
    stats.requestsPerMinute.push(now);
    stats.lastRequestTime = now;
    return true;
  }

  calculateRpm(port) {
    const stats = this.portStats.get(port);
    if (!stats) {
      return 0;
    }
    const now = Date.now();
    stats.requestsPerMinute = stats.requestsPerMinute.filter((value) => now - value < 60000);
    return stats.requestsPerMinute.length;
  }

  getPortStatus(port) {
    const stats = this.portStats.get(port);
    if (!stats) {
      return null;
    }
    const currentRpm = this.calculateRpm(port);
    return {
      port,
      total_requests: stats.totalRequests,
      current_rpm: currentRpm,
      rpm_limit: stats.rpmLimit,
      usage_percent: stats.rpmLimit > 0 ? (currentRpm / stats.rpmLimit) * 100 : 0,
      last_request: stats.lastRequestTime,
    };
  }

  getAllStatus() {
    return [...this.portStats.keys()].sort((a, b) => a - b).map((port) => this.getPortStatus(port));
  }

  setRpmLimit(port, limit) {
    const stats = this.portStats.get(port);
    if (!stats) {
      return false;
    }
    stats.rpmLimit = Number(limit);
    return true;
  }

  resetStats(port = null) {
    const targets = port === null ? [...this.portStats.keys()] : [Number(port)];
    for (const currentPort of targets) {
      const stats = this.portStats.get(currentPort);
      if (!stats) {
        continue;
      }
      stats.totalRequests = 0;
      stats.requestsPerMinute = [];
      stats.lastRequestTime = null;
    }
  }

  printStatus() {
    console.log(`\n${"=".repeat(80)}`);
    console.log(`请求监控 - ${new Date().toLocaleString("zh-CN", { hour12: false })}`);
    console.log("=".repeat(80));
    console.log("端口     总请求      当前RPM     限制         使用率       状态");
    console.log("-".repeat(80));

    for (const status of this.getAllStatus()) {
      const percent = status.usage_percent;
      let state = "空闲";
      if (percent >= 100) {
        state = "超载";
      } else if (percent >= 80) {
        state = "警告";
      } else if (status.current_rpm > 0) {
        state = "正常";
      }

      console.log(
        `${String(status.port).padEnd(8)}${String(status.total_requests).padEnd(12)}${String(
          status.current_rpm
        ).padEnd(12)}${String(status.rpm_limit).padEnd(12)}${percent
          .toFixed(1)
          .padStart(6)}%      ${state}`
      );
    }

    console.log("=".repeat(80));
  }
}

const monitor = new RequestMonitor();

function readJsonBody(request) {
  return new Promise((resolve, reject) => {
    let body = "";
    request.on("data", (chunk) => {
      body += chunk;
    });
    request.on("end", () => {
      if (!body) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(body));
      } catch (error) {
        reject(new Error("请求体不是合法 JSON"));
      }
    });
    request.on("error", reject);
  });
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, { "Content-Type": "application/json; charset=utf-8" });
  response.end(JSON.stringify(payload));
}

async function startMonitorServer() {
  const server = http.createServer(async (request, response) => {
    const url = new URL(request.url, "http://127.0.0.1");
    const recordMatch = url.pathname.match(/^\/monitor\/record\/(\d+)$/);
    const statusMatch = url.pathname.match(/^\/monitor\/status\/(\d+)$/);
    const limitMatch = url.pathname.match(/^\/monitor\/limit\/(\d+)$/);

    try {
      if (request.method === "POST" && recordMatch) {
        const port = Number(recordMatch[1]);
        monitor.recordRequest(port);
        sendJson(response, 200, { success: true });
        return;
      }

      if (request.method === "GET" && statusMatch) {
        const port = Number(statusMatch[1]);
        sendJson(response, 200, monitor.getPortStatus(port));
        return;
      }

      if (request.method === "GET" && url.pathname === "/monitor/status") {
        sendJson(response, 200, monitor.getAllStatus());
        return;
      }

      if (request.method === "POST" && limitMatch) {
        const port = Number(limitMatch[1]);
        const data = await readJsonBody(request);
        monitor.setRpmLimit(port, data.limit || 60);
        sendJson(response, 200, { success: true });
        return;
      }

      if (request.method === "POST" && url.pathname === "/monitor/reset") {
        const data = await readJsonBody(request);
        monitor.resetStats(data.port ?? null);
        sendJson(response, 200, { success: true });
        return;
      }

      sendJson(response, 404, { message: "Not Found" });
    } catch (error) {
      sendJson(response, 500, { message: error.message });
    }
  });

  server.listen(9999, "127.0.0.1", () => {
    console.log("监控服务器启动在 http://127.0.0.1:9999");
  });
}

function consoleMode() {
  console.log("请求监控工具 - 控制台模式");
  console.log("=".repeat(80));
  console.log("命令:");
  console.log("  r <port>  - 记录端口请求 (例如: r 8081)");
  console.log("  s         - 显示所有端口状态");
  console.log("  reset     - 重置所有统计");
  console.log("  q         - 退出");
  console.log("=".repeat(80));

  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  rl.setPrompt("\n> ");
  rl.prompt();

  rl.on("line", (line) => {
    const cmd = line.trim().toLowerCase();
    if (cmd === "q") {
      rl.close();
      return;
    }
    if (cmd === "s") {
      monitor.printStatus();
      rl.prompt();
      return;
    }
    if (cmd === "reset") {
      monitor.resetStats();
      console.log("已重置所有统计");
      rl.prompt();
      return;
    }
    if (cmd.startsWith("r ")) {
      const port = Number(cmd.split(/\s+/)[1]);
      if (!Number.isFinite(port)) {
        console.log("格式错误，使用: r <端口>");
        rl.prompt();
        return;
      }
      monitor.recordRequest(port);
      console.log(`已记录端口 ${port} 的请求，当前RPM: ${monitor.calculateRpm(port)}`);
      rl.prompt();
      return;
    }
    console.log("未知命令");
    rl.prompt();
  });

  rl.on("close", () => {
    console.log("\n退出监控工具");
  });
}

setInterval(() => {
  for (const port of [8081, 8082, 8083, 8084, 8085, 8086, 8087]) {
    monitor.calculateRpm(port);
  }
}, 10000);

if (process.argv[2] === "server") {
  startMonitorServer().catch((error) => {
    console.error(`启动监控服务失败: ${error.message}`);
    process.exitCode = 1;
  });
} else {
  consoleMode();
}
