#!/usr/bin/env bash
# 使用方式 chmod +x ./7god-oneclick.sh && bash ./7god-oneclick.sh
set -euo pipefail

if [[ -t 1 ]]; then
  R=$'\033[0;31m'; G=$'\033[0;32m'; Y=$'\033[1;33m'; B=$'\033[0;34m'; C=$'\033[0;36m'; NC=$'\033[0m'
else
  R=''; G=''; Y=''; B=''; C=''; NC=''
fi

info() { printf "${B}[INFO]${NC} %s\n" "$1"; }
warn() { printf "${Y}[WARN]${NC} %s\n" "$1"; }
error() { printf "${R}[ERROR]${NC} %s\n" "$1" >&2; }
ok() { printf "${G}[OK]${NC} %s\n" "$1"; }

APP_NAME="7god"
DEFAULT_REPO_URL="https://github.com/tztmr/7god.git"
DEFAULT_BRANCH="main"
DEFAULT_INSTALL_DIR="/opt/7god"
STATE_DIR="${HOME}/.7god-oneclick"
STATE_FILE="${STATE_DIR}/state.env"
DOCKER_COMPOSE_CMD=()

trim() {
  local v="${1:-}"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

run_root() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; return $?; fi
  if command_exists sudo; then sudo "$@"; return $?; fi
  return 1
}

ensure_root_capability() {
  if [[ "$(id -u)" -eq 0 ]]; then return 0; fi
  if ! command_exists sudo; then
    error "请使用 root 运行，或先安装 sudo"
    exit 1
  fi
  if ! sudo -n true 2>/dev/null; then
    error "当前账号需要 sudo 免密或交互授权后再运行"
    exit 1
  fi
}

prompt_default() {
  local prompt="$1" def="${2:-}" val=""
  if [[ -n "$def" ]]; then
    printf '%s [%s]: ' "$prompt" "$def" >&2
  else
    printf '%s: ' "$prompt" >&2
  fi
  read -r val
  val="$(trim "$val")"
  [[ -z "$val" ]] && val="$def"
  printf '%s' "$val"
}

ask_yes_no() {
  local prompt="$1" def="${2:-y}" ans="" hint="[Y/n]"
  [[ "$def" == "n" ]] && hint="[y/N]"
  while true; do
    printf '%s %s: ' "$prompt" "$hint" >&2
    read -r ans
    ans="$(trim "$ans")"
    [[ -z "$ans" ]] && ans="$def"
    ans="$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')"
    case "$ans" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) warn "请输入 y 或 n" ;;
    esac
  done
}

ensure_state_dir() {
  mkdir -p "$STATE_DIR"
  chmod 700 "$STATE_DIR" 2>/dev/null || true
}

save_state() {
  local install_dir="$1" repo_url="$2" branch="$3" ports="$4" domain="${5:-}" acme_email="${6:-}" deploy_mode="${7:-systemd}" bind_local="${8:-false}"
  ensure_state_dir
  cat > "$STATE_FILE" <<EOF
INSTALL_DIR='${install_dir}'
REPO_URL='${repo_url}'
BRANCH='${branch}'
PORTS='${ports}'
DOMAIN='${domain}'
ACME_EMAIL='${acme_email}'
DEPLOY_MODE='${deploy_mode}'
BIND_LOCAL='${bind_local}'
EOF
  chmod 600 "$STATE_FILE" 2>/dev/null || true
}

load_state() {
  [[ -f "$STATE_FILE" ]] || return 1
  set +u
  source "$STATE_FILE"
  set -u
  DEPLOY_MODE="${DEPLOY_MODE:-systemd}"
  BIND_LOCAL="${BIND_LOCAL:-false}"
  [[ -n "${INSTALL_DIR:-}" && -n "${REPO_URL:-}" && -n "${BRANCH:-}" && -n "${PORTS:-}" ]]
}

pick_compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD=(docker compose)
  elif command_exists docker-compose; then
    DOCKER_COMPOSE_CMD=(docker-compose)
  else
    error "未找到 docker compose"
    return 1
  fi
}

validate_port() {
  [[ "$1" =~ ^[0-9]+$ ]] || return 1
  (( "$1" >= 1 && "$1" <= 65535 ))
}

validate_ports_csv() {
  local csv="$1" port
  IFS=',' read -r -a arr <<< "$csv"
  [[ "${#arr[@]}" -gt 0 ]] || return 1
  for port in "${arr[@]}"; do
    port="$(trim "$port")"
    validate_port "$port" || return 1
  done
}

install_basic_packages() {
  info "检查并安装 Git / Curl / Java 17"
  if command_exists apt-get; then
    run_root apt-get update -y -qq
    run_root apt-get install -y -qq git curl ca-certificates openjdk-17-jre
  elif command_exists dnf; then
    run_root dnf install -y -q git curl ca-certificates java-17-openjdk
  elif command_exists yum; then
    run_root yum install -y -q git curl ca-certificates java-17-openjdk
  else
    error "不支持的系统包管理器，请手动安装 Git/Curl/Java 17"
    return 1
  fi
  ok "基础依赖安装完成"
}

install_docker_if_needed() {
  if command_exists docker; then
    pick_compose_cmd
    run_root systemctl enable docker 2>/dev/null || true
    run_root systemctl start docker 2>/dev/null || true
    return 0
  fi

  info "检测到未安装 Docker，开始自动安装"
  if command_exists apt-get; then
    run_root apt-get update -y -qq
    run_root apt-get install -y -qq ca-certificates curl gnupg lsb-release
    curl -fsSL https://get.docker.com | run_root bash
  elif command_exists dnf; then
    run_root dnf -y -q install dnf-plugins-core
    run_root dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    run_root dnf -y -q install docker-ce docker-ce-cli containerd.io docker-compose-plugin
  elif command_exists yum; then
    run_root yum -y -q install yum-utils
    run_root yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    run_root yum -y -q install docker-ce docker-ce-cli containerd.io docker-compose-plugin
  else
    error "不支持的系统包管理器，请手动安装 Docker"
    return 1
  fi

  run_root systemctl enable docker
  run_root systemctl start docker
  pick_compose_cmd
  ok "Docker 安装完成"
}

install_nginx_if_needed() {
  if command_exists nginx; then
    run_root systemctl enable nginx 2>/dev/null || true
    run_root systemctl start nginx 2>/dev/null || true
    return 0
  fi

  info "检测到未安装 Nginx，开始自动安装"
  if command_exists apt-get; then
    run_root apt-get update -y -qq
    run_root apt-get install -y -qq nginx
  elif command_exists dnf; then
    run_root dnf install -y -q nginx
  elif command_exists yum; then
    run_root yum install -y -q nginx
  else
    error "无法自动安装 Nginx，请手动安装后重试"
    return 1
  fi
  run_root systemctl enable nginx
  run_root systemctl start nginx
  ok "Nginx 安装完成"
}

install_certbot_if_needed() {
  if command_exists certbot; then
    return 0
  fi

  info "检测到未安装 Certbot，开始自动安装"
  if command_exists apt-get; then
    run_root apt-get update -y -qq
    run_root apt-get install -y -qq certbot python3-certbot-nginx
  elif command_exists dnf; then
    run_root dnf install -y -q certbot python3-certbot-nginx || run_root dnf install -y -q certbot-nginx
  elif command_exists yum; then
    run_root yum install -y -q certbot python3-certbot-nginx || run_root yum install -y -q certbot-nginx
  else
    error "无法自动安装 Certbot，请手动安装后重试"
    return 1
  fi
  command_exists certbot || { error "Certbot 安装失败"; return 1; }
  ok "Certbot 安装完成"
}

allow_firewall_port() {
  local port="$1"
  if command_exists ufw; then
    if ufw status 2>/dev/null | grep -q "Status: active"; then
      run_root ufw allow "${port}/tcp" >/dev/null 2>&1 || true
      ok "UFW 已放行 ${port}/tcp"
    fi
  fi
  if command_exists firewall-cmd && firewall-cmd --state >/dev/null 2>&1; then
    run_root firewall-cmd --permanent --add-port="${port}/tcp" >/dev/null 2>&1 || true
    run_root firewall-cmd --reload >/dev/null 2>&1 || true
    ok "firewalld 已放行 ${port}/tcp"
  fi
}

ensure_https_firewall_ports() {
  allow_firewall_port 80
  allow_firewall_port 443
}

nginx_conf_dir() {
  if [[ -d /etc/nginx/conf.d ]]; then
    printf '/etc/nginx/conf.d'
  else
    printf '/etc/nginx/sites-available'
  fi
}

setup_nginx_proxy_http() {
  local domain="$1" upstream_port="$2"
  local conf_dir conf_file tmp_file

  conf_dir="$(nginx_conf_dir)"
  conf_file="${conf_dir}/${domain}.conf"
  run_root mkdir -p "$conf_dir"

  tmp_file="$(mktemp)"
  cat > "$tmp_file" <<EOF
server {
    listen 80;
    server_name ${domain};

    location / {
        proxy_pass http://127.0.0.1:${upstream_port};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
    }
}
EOF

  run_root install -m 0644 "$tmp_file" "$conf_file"
  rm -f "$tmp_file"

  if [[ -d /etc/nginx/sites-enabled ]]; then
    run_root ln -sf "${conf_file}" "/etc/nginx/sites-enabled/${domain}.conf"
    run_root rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
  fi

  run_root nginx -t
  run_root systemctl reload nginx 2>/dev/null || run_root nginx -s reload
}

clone_or_update_repo() {
  local install_dir="$1" repo_url="$2" branch="$3"
  if [[ -d "${install_dir}/.git" ]]; then
    info "检测到已有代码，开始更新"
    git -C "$install_dir" fetch origin "$branch"
    git -C "$install_dir" checkout "$branch"
    git -C "$install_dir" pull --ff-only origin "$branch"
  else
    run_root mkdir -p "$(dirname "$install_dir")"
    git clone --branch "$branch" "$repo_url" "$install_dir"
  fi
}

ensure_jar() {
  local install_dir="$1"
  local jar_path="${install_dir}/7god.jar"
  local root_jar_path="/root/7god.jar"
  local jar_url=""

  if [[ -f "$jar_path" ]]; then
    ok "检测到已有 7god.jar"
    return 0
  fi

  if [[ -f "$root_jar_path" ]]; then
    info "检测到 /root/7god.jar，开始自动迁移到 ${jar_path}"
    run_root mkdir -p "$install_dir"
    run_root mv "$root_jar_path" "$jar_path"
    ok "已从 /root 自动迁移 7god.jar"
    return 0
  fi

  warn "仓库默认不包含 7god.jar（GitHub 文件大小限制）"
  jar_url="$(prompt_default "请输入 7god.jar 直链下载地址（留空则手动放置后回车）" "")"

  if [[ -n "$jar_url" ]]; then
    info "开始下载 7god.jar"
    curl -fL "$jar_url" -o "$jar_path"
    ok "7god.jar 下载完成"
    return 0
  fi

  error "未找到 ${jar_path}，请先上传 7god.jar 到该目录后重试"
  return 1
}

write_docker_compose_file() {
  local install_dir="$1" port="$2" bind_local="$3"
  local host_bind="${port}:${port}"
  [[ "$bind_local" == "true" ]] && host_bind="127.0.0.1:${port}:${port}"

  cat > "${install_dir}/docker-compose.yml" <<EOF
services:
  7god:
    image: eclipse-temurin:17-jre
    container_name: 7god
    restart: unless-stopped
    working_dir: /app
    command: ["java", "-jar", "/app/7god.jar", "--server.port=${port}"]
    volumes:
      - ${install_dir}:/app
    ports:
      - "${host_bind}"
EOF
}

write_systemd_template() {
  local install_dir="$1"
  local tmp_file
  tmp_file="$(mktemp)"
  cat > "$tmp_file" <<EOF
[Unit]
Description=7god Sign Service on port %i
After=network.target

[Service]
Type=simple
WorkingDirectory=${install_dir}
ExecStart=/usr/bin/java -jar ${install_dir}/7god.jar --server.port=%i
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  run_root install -m 0644 "$tmp_file" /etc/systemd/system/7god@.service
  rm -f "$tmp_file"
  run_root systemctl daemon-reload
  ok "systemd 模板服务写入完成"
}

enable_ports() {
  local csv="$1" port
  IFS=',' read -r -a arr <<< "$csv"
  for port in "${arr[@]}"; do
    port="$(trim "$port")"
    run_root systemctl enable --now "7god@${port}"
    allow_firewall_port "$port"
    ok "已启动 7god@${port}"
  done
}

stop_ports() {
  local csv="$1" port
  IFS=',' read -r -a arr <<< "$csv"
  for port in "${arr[@]}"; do
    port="$(trim "$port")"
    run_root systemctl stop "7god@${port}" 2>/dev/null || true
    run_root systemctl disable "7god@${port}" 2>/dev/null || true
  done
}

deploy() {
  ensure_root_capability
  install_basic_packages

  local install_dir repo_url branch ports
  install_dir="$(prompt_default "部署目录" "$DEFAULT_INSTALL_DIR")"
  repo_url="$(prompt_default "Git 仓库地址" "$DEFAULT_REPO_URL")"
  branch="$(prompt_default "分支名" "$DEFAULT_BRANCH")"
  ports="$(prompt_default "部署端口，多个端口用逗号分隔" "8081")"

  validate_ports_csv "$ports" || { error "端口格式无效: $ports"; return 1; }

  clone_or_update_repo "$install_dir" "$repo_url" "$branch"
  ensure_jar "$install_dir"
  write_systemd_template "$install_dir"
  enable_ports "$ports"
  save_state "$install_dir" "$repo_url" "$branch" "$ports" "" "" "systemd" "false"

  local server_ip
  server_ip="$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || true)"
  [[ -z "$server_ip" ]] && server_ip="服务器IP"

  echo
  ok "7god 部署完成"
  echo "部署目录: ${install_dir}"
  echo "已启动端口: ${ports}"
  echo "本机接口: http://127.0.0.1:$(printf '%s' "$ports" | cut -d',' -f1)/api/douyin/sign"
  echo "远程接口: http://${server_ip}:$(printf '%s' "$ports" | cut -d',' -f1)/api/douyin/sign"
  echo
}

deploy_docker() {
  ensure_root_capability
  install_basic_packages
  install_docker_if_needed

  local install_dir repo_url branch port bind_local
  install_dir="$(prompt_default "部署目录" "$DEFAULT_INSTALL_DIR")"
  repo_url="$(prompt_default "Git 仓库地址" "$DEFAULT_REPO_URL")"
  branch="$(prompt_default "分支名" "$DEFAULT_BRANCH")"
  port="$(prompt_default "Docker 映射端口" "${PORTS:-7181}")"
  validate_port "$port" || { error "端口无效: $port"; return 1; }

  bind_local="true"
  if ask_yes_no "是否允许 Docker 直接暴露到公网（不推荐）" "n"; then
    bind_local="false"
  fi

  clone_or_update_repo "$install_dir" "$repo_url" "$branch"
  ensure_jar "$install_dir"
  write_docker_compose_file "$install_dir" "$port" "$bind_local"

  info "启动 Docker 容器"
  (cd "$install_dir" && "${DOCKER_COMPOSE_CMD[@]}" up -d)

  if [[ "$bind_local" == "false" ]]; then
    allow_firewall_port "$port"
  fi

  save_state "$install_dir" "$repo_url" "$branch" "$port" "" "" "docker" "$bind_local"

  echo
  ok "7god Docker 部署完成"
  echo "部署目录: ${install_dir}"
  echo "容器名称: 7god"
  echo "绑定端口: ${port}"
  if [[ "$bind_local" == "true" ]]; then
    echo "本机接口: http://127.0.0.1:${port}/api/douyin/sign"
    echo "说明: 当前仅本机可访问，适合配合现有 Nginx 的 80/443 统一反代"
  else
    local server_ip
    server_ip="$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || true)"
    [[ -z "$server_ip" ]] && server_ip="服务器IP"
    echo "远程接口: http://${server_ip}:${port}/api/douyin/sign"
  fi
  echo
}

status_app() {
  load_state || { error "未找到部署记录，请先执行部署"; return 1; }
  if [[ "$DEPLOY_MODE" == "docker" ]]; then
    pick_compose_cmd
    (cd "$INSTALL_DIR" && "${DOCKER_COMPOSE_CMD[@]}" ps)
    return 0
  fi

  local port
  IFS=',' read -r -a arr <<< "$PORTS"
  for port in "${arr[@]}"; do
    port="$(trim "$port")"
    run_root systemctl status "7god@${port}" --no-pager || true
  done
}

logs_app() {
  load_state || { error "未找到部署记录，请先执行部署"; return 1; }
  if [[ "$DEPLOY_MODE" == "docker" ]]; then
    pick_compose_cmd
    (cd "$INSTALL_DIR" && "${DOCKER_COMPOSE_CMD[@]}" logs -f --tail 100)
    return 0
  fi

  local port
  port="$(prompt_default "查看哪个端口的日志" "$(printf '%s' "$PORTS" | cut -d',' -f1)")"
  validate_port "$port" || { error "端口无效"; return 1; }
  run_root journalctl -u "7god@${port}" -f -n 100
}

restart_app() {
  load_state || { error "未找到部署记录，请先执行部署"; return 1; }
  if [[ "$DEPLOY_MODE" == "docker" ]]; then
    pick_compose_cmd
    (cd "$INSTALL_DIR" && "${DOCKER_COMPOSE_CMD[@]}" restart)
    ok "Docker 容器已重启"
    return 0
  fi

  local port
  IFS=',' read -r -a arr <<< "$PORTS"
  for port in "${arr[@]}"; do
    port="$(trim "$port")"
    run_root systemctl restart "7god@${port}"
    ok "已重启 7god@${port}"
  done
}

update_app() {
  load_state || { error "未找到部署记录，请先执行部署"; return 1; }
  ensure_root_capability
  clone_or_update_repo "$INSTALL_DIR" "$REPO_URL" "$BRANCH"
  ensure_jar "$INSTALL_DIR"
  if [[ "$DEPLOY_MODE" == "docker" ]]; then
    pick_compose_cmd
    write_docker_compose_file "$INSTALL_DIR" "$(printf '%s' "$PORTS" | cut -d',' -f1)" "$BIND_LOCAL"
    (cd "$INSTALL_DIR" && "${DOCKER_COMPOSE_CMD[@]}" up -d)
    ok "Docker 模式代码更新完成"
  else
    write_systemd_template "$INSTALL_DIR"
    restart_app
    ok "代码更新并重启完成"
  fi
}

nginx_ssl() {
  load_state || { error "未找到部署记录，请先执行部署"; return 1; }
  ensure_root_capability
  install_nginx_if_needed || return 1
  install_certbot_if_needed || return 1

  local port domain acme_email
  port="$(prompt_default "要反代的 7god 端口" "$(printf '%s' "$PORTS" | cut -d',' -f1)")"
  validate_port "$port" || { error "端口无效: $port"; return 1; }

  local http_code
  http_code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:${port}/" || true)"
  if [[ -z "$http_code" || "$http_code" == "000" ]]; then
    error "本机 127.0.0.1:${port} 不可达，请先确认 7god@${port} 正常运行"
    return 1
  fi

  domain="$(prompt_default "绑定域名（如 sign.example.com）" "${DOMAIN:-}")"
  [[ -z "$domain" ]] && { error "域名不能为空"; return 1; }
  acme_email="$(prompt_default "证书邮箱" "${ACME_EMAIL:-admin@${domain}}")"

  ensure_https_firewall_ports
  setup_nginx_proxy_http "$domain" "$port"
  run_root certbot --nginx -d "$domain" --redirect -m "$acme_email" --agree-tos --non-interactive
  save_state "$INSTALL_DIR" "$REPO_URL" "$BRANCH" "$PORTS" "$domain" "$acme_email" "$DEPLOY_MODE" "$BIND_LOCAL"

  ok "Nginx 反代 + SSL 已完成"
  echo "HTTPS 地址: https://${domain}"
  echo "接口地址: https://${domain}/api/douyin/sign"
}

uninstall_app() {
  load_state || { error "未找到部署记录，请先执行部署"; return 1; }
  if [[ "$DEPLOY_MODE" == "docker" ]]; then
    pick_compose_cmd
    warn "将停止并删除 Docker 容器，默认保留目录 ${INSTALL_DIR}"
    if ask_yes_no "确认继续卸载" "n"; then
      (cd "$INSTALL_DIR" && "${DOCKER_COMPOSE_CMD[@]}" down)
      if ask_yes_no "是否同时删除部署目录（不可恢复）" "n"; then
        run_root rm -rf "$INSTALL_DIR"
        ok "部署目录已删除"
      fi
      ok "Docker 模式卸载完成"
    fi
    return 0
  fi

  warn "将停止并移除 systemd 服务，默认保留目录 ${INSTALL_DIR}"
  if ask_yes_no "确认继续卸载" "n"; then
    stop_ports "$PORTS"
    run_root rm -f /etc/systemd/system/7god@.service
    run_root systemctl daemon-reload
    if ask_yes_no "是否同时删除部署目录（不可恢复）" "n"; then
      run_root rm -rf "$INSTALL_DIR"
      ok "部署目录已删除"
    fi
    ok "卸载完成"
  fi
}

print_menu() {
  echo
  echo "============= 7god 一键脚本 ============="
  echo "1) 一键部署（systemd）"
  echo "2) Docker部署（配合现有Nginx）"
  echo "3) 查看状态"
  echo "4) 查看日志"
  echo "5) 重启服务"
  echo "6) 更新代码并重启"
  echo "7) Nginx反代+SSL（申请证书）"
  echo "8) 卸载"
  echo "0) 退出"
  echo "========================================="
}

main() {
  while true; do
    print_menu
    printf '请选择 [0-8]: ' >&2
    read -r choice
    choice="$(trim "${choice}")"
    case "$choice" in
      1) deploy ;;
      2) deploy_docker ;;
      3) status_app ;;
      4) logs_app ;;
      5) restart_app ;;
      6) update_app ;;
      7) nginx_ssl ;;
      8) uninstall_app ;;
      0) exit 0 ;;
      *) warn "无效选项" ;;
    esac
  done
}

main "$@"
