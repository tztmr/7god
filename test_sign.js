#!/usr/bin/env node
const { URL, URLSearchParams } = require("node:url");
const { SevenGodClient } = require("./lib/seven_god_client");

async function get7GodSign(url, headers) {
  const client = new SevenGodClient({ port: Number(process.env.SEVEN_GOD_PORT || 8081) });
  return client.callSignApi(url, headers);
}

async function main() {
  const timestamp13 = Date.now();
  const url = new URL("https://api5-normal-sinfonlinea.fqnovel.com/novel/player/video_detail/v1/");
  url.search = new URLSearchParams({
    iid: "2613984089657241",
    device_id: "2613984089407385",
    ac: "wifi",
    channel: "xiaomi_8662_64",
    aid: "8662",
    app_name: "novelread",
    version_code: "70732",
    version_name: "7.0.7.32",
    device_platform: "android",
    os: "android",
    ssmix: "a",
    device_type: "2210FF6DJI",
    device_brand: "Xiaomi",
    language: "zh",
    os_api: "34",
    os_version: "14",
    manifest_version_code: "70732",
    resolution: "1220*2712",
    dpi: "405",
    update_version_code: "70732",
    _rticket: String(timestamp13),
    host_abi: "arm64-v8a",
    dragon_device_type: "phone",
    pv_player: "70732",
    compliance_status: "0",
    need_personal_recommend: "1",
    player_so_load: "1",
    is_android_pad_screen: "0",
    rom_version: "miui_V130_V13.1.3.8.YLGIEUXM",
    cdid: "d78246f0-3e5b-4c3d-a3cf-882d9411ee69",
  }).toString();

  const apiHeaders = {
    "User-Agent":
      "com.phoenix.read/70732 (Linux; U; Android 14; zh_CN; 2210FF6DJI; Build/AUB5.221015.827; Cronet/TTNetVersion:6f1e308d 2025-12-08 QuicVersion:21ac1950 2025-11-18)",
    Accept: "application/json;",
    "x-xs-from-web": "0",
    "x-ss-req-ticket": String(timestamp13),
    "x-reading-request": `${timestamp13}-1324707899`,
    "x-vc-bdturing-sdk-version": "3.7.2.cn",
    "sdk-version": "2",
    "passport-sdk-version": "50340",
    "x-ss-dp": "8662",
    Cookie:
      "store-region=cn-sd; store-region-src=did; install_id=2613984089657241; ttreq=1$5d5c1fc21db2860f4b6db6d7f9b1734b70fcc244; passport_csrf_token=0eb348fec068fca39a4f49ab993364d8; passport_csrf_token_default=0eb348fec068fca39a4f49ab993364d8; odin_tt=6b0b6a96654c58b284cf543d59f264ae9e19b250c150333f291f63cbe2647d9a6b458307a0e4785bccaf58bd6eafc1dfe0b7d8c76adb156d7ca02e3029063618542429f5576153153abe9f29005e5056",
  };

  console.log("=".repeat(60));
  console.log("七神签名服务测试");
  console.log("=".repeat(60));
  console.log(`\n测试URL: ${url.toString().slice(0, 80)}...`);
  console.log(`请求头数量: ${Object.keys(apiHeaders).length}`);
  console.log("\n正在调用签名服务...");

  const result = await get7GodSign(url.toString(), apiHeaders);

  console.log(`\n${"=".repeat(60)}`);
  console.log("签名服务返回结果:");
  console.log("=".repeat(60));
  console.log(JSON.stringify(result, null, 2));

  if (!result.data) {
    console.log("\n调用失败，未返回签名数据");
    if (result.error) {
      console.log(`错误信息: ${result.error}`);
    }
    return;
  }

  const signData = result.data;
  const expectedSigns = [
    "X-Gorgon",
    "X-Khronos",
    "X-Argus",
    "X-Ladon",
    "X-Helios",
    "X-Medusa",
    "X-Soter",
  ];

  console.log(`\n${"=".repeat(60)}`);
  console.log("生成的签名列表:");
  console.log("=".repeat(60));
  console.log(`\n实际返回 ${Object.keys(signData).length} 个签名:`);
  Object.entries(signData).forEach(([key, value], index) => {
    const preview = String(value).slice(0, 50);
    console.log(`  ${index + 1}. ${key}: ${preview}...`);
  });

  console.log(`\n${"-".repeat(60)}`);
  console.log("签名支持检测:");
  console.log("-".repeat(60));
  const supported = expectedSigns.filter((name) => name in signData);
  for (const sign of expectedSigns) {
    console.log(`  ${supported.includes(sign) ? "OK" : "NO"} ${sign}`);
  }

  console.log(`\n${"=".repeat(60)}`);
  console.log(`检测结果: ${supported.length}/7 个签名已支持`);
  console.log("=".repeat(60));
}

main().catch((error) => {
  console.error(`执行失败: ${error.message}`);
  process.exitCode = 1;
});
