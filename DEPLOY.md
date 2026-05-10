# 7god 部署说明

## 仓库内容

本仓库提供的是：

- Node.js 调用脚本
- Linux 一键部署脚本 `7god-oneclick.sh`
- 部署说明

本仓库不直接包含 `7god.jar`，原因是该文件约 335MB，超过 GitHub 常规文件限制。

## 准备工作

你需要准备以下任一方式：

1. 提前把 `7god.jar` 上传到服务器
2. 准备一个可直接下载的 `7god.jar` 链接

## 一键部署

```bash
chmod +x ./7god-oneclick.sh
bash ./7god-oneclick.sh
```

脚本支持：

- 自动安装 Java 17 / Git / Curl
- 克隆或更新仓库代码
- 写入 `systemd` 模板服务
- 单端口或多端口部署 `7god.jar`
- 查看状态 / 日志 / 重启 / 更新 / 卸载
- 自动放行防火墙端口

## 推荐部署方式

### 单端口

适合先验证服务是否可用。

- 端口：`8081`
- systemd 服务：`7god@8081`

### 多端口

适合并发调用。

- 常用端口：`8081,8082,8083,8084,8085,8086,8087`
- systemd 会按实例方式启动：
  - `7god@8081`
  - `7god@8082`
  - `7god@8083`
  - ...

## 手动部署命令

如果你不想走脚本，也可以手动部署：

```bash
sudo apt update
sudo apt install -y openjdk-17-jre git curl
sudo mkdir -p /opt/7god
sudo chown -R $USER:$USER /opt/7god
```

把 `7god.jar` 放到 `/opt/7god/7god.jar` 后执行：

```bash
cd /opt/7god
java -jar 7god.jar --server.port=8081
```

## 常见问题

### 1. GitHub 仓库里为什么没有 `7god.jar`

因为文件超过 GitHub 常规上传限制，所以仓库只保存脚本和说明。

### 2. Node.js 脚本一定要部署到服务器吗

不一定。

- `7god.jar` 才是核心服务端
- `demo.js`、`test_sign.js`、`api_client_demo.js` 更适合做调用端或测试端

### 3. 远程调用时为什么还是访问 `127.0.0.1`

请把脚本里的调用地址改成服务器 IP，或者通过环境变量扩展你的调用地址。
