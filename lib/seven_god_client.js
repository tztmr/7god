const { URL } = require("node:url");

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

class SevenGodClient {
  constructor(options = {}) {
    this.host = options.host || "127.0.0.1";
    this.port = Number(options.port || 8081);
    this.timeout = Number(options.timeout || 10000);
    this.requestCount = 0;
    this.onRequest = typeof options.onRequest === "function" ? options.onRequest : null;
  }

  get baseUrl() {
    return `http://${this.host}:${this.port}`;
  }

  async postJson(pathname, payload) {
    const url = new URL(pathname, `${this.baseUrl}/`);
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(this.timeout),
    });

    const text = await response.text();
    let data;
    try {
      data = text ? JSON.parse(text) : {};
    } catch (error) {
      throw new Error(`服务返回了非 JSON 数据: ${text.slice(0, 200)}`);
    }

    if (!response.ok) {
      const message = data.message || `HTTP ${response.status}`;
      throw new Error(message);
    }

    return data;
  }

  async callSignApi(url, headers = { "User-Agent": "test", Cookie: "test" }) {
    try {
      const result = await this.postJson("/api/douyin/sign", { url, headers });
      this.requestCount += 1;
      if (this.onRequest) {
        await this.onRequest({ port: this.port, url, result, success: true });
      }
      return result;
    } catch (error) {
      if (this.onRequest) {
        await this.onRequest({ port: this.port, url, result: null, success: false, error });
      }
      return { error: error.message };
    }
  }

  async testMultipleRequests({ count = 10, interval = 1000, url, headers } = {}) {
    const testUrl =
      url || "https://api5-normal-sinfonlinea.fqnovel.com/novel/player/video_detail/v1/?iid=test";
    console.log(`开始测试: ${this.baseUrl}`);
    console.log(`计划发送 ${count} 次请求，间隔 ${interval / 1000} 秒`);
    console.log("-".repeat(50));

    for (let index = 0; index < count; index += 1) {
      const result = await this.callSignApi(testUrl, headers);
      console.log(`[${index + 1}/${count}] 请求完成`);
      if (result.code === 200) {
        console.log("  成功获取签名");
      } else {
        console.log(`  失败: ${result.message || result.error || "未知错误"}`);
      }

      if (index < count - 1) {
        await delay(interval);
      }
    }

    console.log("-".repeat(50));
    console.log(`测试完成，总请求数: ${this.requestCount}`);
  }
}

module.exports = {
  SevenGodClient,
  delay,
};
