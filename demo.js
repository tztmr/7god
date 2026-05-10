#!/usr/bin/env node
const { URL, URLSearchParams } = require("node:url");
const { SevenGodClient } = require("./lib/seven_god_client");

async function get7God(url, headers) {
  const client = new SevenGodClient({ port: Number(process.env.SEVEN_GOD_PORT || 8081) });
  const response = await client.callSignApi(url, headers);
  console.log("七神:", JSON.stringify(response, null, 2));
  return response.data;
}

async function main() {
  const timestamp = Math.floor(Date.now() / 1000);
  const timestamp13 = Date.now();
  const seriesId = "7528625248594316313";
  const url = new URL("https://api5-normal-sinfonlinea.fqnovel.com/novel/player/video_detail/v1/");
  const params = new URLSearchParams({
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
  });
  url.search = params.toString();

  const jsonData = JSON.stringify({
    biz_param: {
      caller_scene: "search",
      detail_page_version: 0,
      disable_digg_stat: false,
      from_video_id: "",
      image_shrink_datas_str:
        "W3siaW1hZ2VfdHlwZSI6MywiaW1hZ2Vfd2lkdGgiOjEwNzgsInNocmlua190eXBlIjozfSx7ImltYWdlX3R5cGUiOjQsImltYWdlX3dpZHRoIjo5OSwic2hyaW5rX3R5cGUiOjR9XQ==",
      need_all_video_definition: false,
      need_mp4_align: false,
      screen_width_px: "1078",
      source: 4,
      use_os_player: false,
      use_server_dns: false,
      video_id_type: 1,
    },
    series_id: seriesId,
  });

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

  const sign = await get7God(url.toString(), apiHeaders);
  const requestHeaders = { ...apiHeaders, ...(sign || {}) };
  const response = await fetch(url, {
    method: "POST",
    headers: requestHeaders,
    body: jsonData,
    signal: AbortSignal.timeout(10000),
  });

  console.log(`timestamp=${timestamp}`);
  console.log("\n结果:", await response.text());
}

main().catch((error) => {
  console.error(`执行失败: ${error.message}`);
  process.exitCode = 1;
});
