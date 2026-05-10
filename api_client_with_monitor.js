#!/usr/bin/env node
const { SevenGodClient, delay } = require("./lib/seven_god_client");

class MonitoredAPIClient extends SevenGodClient {
  constructor(options = {}) {
    super(options);
    this.monitorBaseUrl = options.monitorBaseUrl || process.env.MONITOR_BASE_URL || "";
    this.retryCount = Number(options.retryCount || process.env.RETRY_COUNT || 1);
  }

  async recordRequest(payload) {
    if (!this.monitorBaseUrl) {
      return;
    }

    const baseUrl = this.monitorBaseUrl.replace(/\/$/, "");
    await fetch(`${baseUrl}/monitor/record/${payload.port}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ success: payload.success, url: payload.url }),
      signal: AbortSignal.timeout(this.timeout),
    });
  }

  async callSignApi(url, headers = { "User-Agent": "test", Cookie: "test" }) {
    let lastResult = { error: "未知错误" };

    for (let attempt = 1; attempt <= this.retryCount; attempt += 1) {
      lastResult = await super.callSignApi(url, headers);
      try {
        await this.recordRequest({
          port: this.port,
          url,
          success: lastResult.code === 200,
        });
      } catch (error) {
        console.warn(`监控记录失败: ${error.message}`);
      }

      if (lastResult.code === 200 || attempt === this.retryCount) {
        return lastResult;
      }

      await delay(300);
    }

    return lastResult;
  }
}

async function testAllPorts() {
  const ports = [8081, 8082, 8083, 8084, 8085, 8086, 8087];
  console.log("=".repeat(60));
  console.log("七神签名服务 - 全端口测试");
  console.log("=".repeat(60));

  for (const port of ports) {
    const client = new MonitoredAPIClient({ port });
    await client.testMultipleRequests({ count: 5, interval: 500 });
    console.log("");
    await delay(2000);
  }

  console.log("=".repeat(60));
  console.log("所有端口测试完成");
  console.log("=".repeat(60));
}

async function stressTestSinglePort(port = 8081, count = 100) {
  console.log(`开始压力测试: 端口 ${port}`);
  console.log(`计划发送 ${count} 次请求（快速连续）`);
  console.log("-".repeat(50));

  const client = new MonitoredAPIClient({ port });
  const testUrl = "https://api5-normal-sinfonlinea.fqnovel.com/novel/player/video_detail/v1/?iid=test";
  let success = 0;
  let failed = 0;

  for (let index = 0; index < count; index += 1) {
    const result = await client.callSignApi(testUrl);

    if (result.code === 200) {
      success += 1;
    } else {
      failed += 1;
      console.log(`[${index + 1}] 失败: ${result.message || result.error || "未知错误"}`);
    }

    if ((index + 1) % 10 === 0) {
      console.log(`进度: ${index + 1}/${count} (成功: ${success}, 失败: ${failed})`);
    }
  }

  console.log("-".repeat(50));
  console.log("压力测试完成");
  console.log(`总请求: ${count}`);
  console.log(`成功: ${success}`);
  console.log(`失败: ${failed}`);
  console.log(`成功率: ${((success / count) * 100).toFixed(1)}%`);
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length > 0) {
    if (args[0] === "all") {
      await testAllPorts();
      return;
    }

    if (args[0] === "stress" && args[1]) {
      const port = Number(args[1]);
      const count = Number(args[2] || 100);
      await stressTestSinglePort(port, count);
      return;
    }

    const port = Number(args[0] || 8081);
    const client = new MonitoredAPIClient({ port });
    await client.testMultipleRequests({ count: 10, interval: 1000 });
    return;
  }

  console.log("使用方法:");
  console.log("  node api_client_with_monitor.js          # 默认测试端口8081");
  console.log("  node api_client_with_monitor.js 8081     # 测试指定端口");
  console.log("  node api_client_with_monitor.js all      # 测试所有端口");
  console.log("  node api_client_with_monitor.js stress 8081 100  # 压力测试");
  console.log("");

  const client = new MonitoredAPIClient({ port: 8081 });
  await client.testMultipleRequests({ count: 10, interval: 1000 });
}

main().catch((error) => {
  console.error(`执行失败: ${error.message}`);
  process.exitCode = 1;
});
