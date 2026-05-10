# 7god Node 工具集

这是一个面向 `7god.jar` 的 Node.js 工具仓库，包含：

- `demo.js`：完整签名调用示例
- `test_sign.js`：检测七神签名返回内容
- `api_client_demo.js`：单端口 / 全端口 / 压测客户端
- `api_client_with_monitor.js`：带监控上报的客户端
- `request_monitor.js`：监控服务和控制台工具
- `7god-oneclick.sh`：Linux 一键部署脚本
- `DEPLOY.md`：部署说明文档

## 说明

- 已将核心 Python 脚本迁移为 Node.js 版本。
- `gui_manager.py` 没有迁移，因为它是基于 Tkinter 的 Windows GUI，直接改成 Node.js 并不划算，也不适合作为服务器端主流程。
- 由于 `7god.jar` 体积约 335MB，超过 GitHub 普通文件限制，仓库默认不包含该文件。

## 运行环境

- Node.js >= 18
- Java 17
- `7god.jar` 需要你自行放到项目根目录，或部署时提供下载地址

## 快速开始

```bash
node -v
java -version
```

```bash
node test_sign.js
node api_client_demo.js 8081
node api_client_demo.js all
node api_client_with_monitor.js stress 8081 100
```

## 监控服务

启动监控 HTTP 服务：

```bash
node request_monitor.js server
```

再启动带监控的客户端：

```bash
MONITOR_BASE_URL=http://127.0.0.1:9999 node api_client_with_monitor.js 8081
```

## 服务器部署

见 [DEPLOY.md](./DEPLOY.md)。
