#!/bin/bash

# ===== 🌈 美化输出配色 =====
RED='\033[0;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
RESET='\033[0m'
BOLD='\033[1m'

prompt() { echo -ne "${YELLOW}$1${RESET}"; }
info()   { echo -e "${GREEN}[信息]${RESET} $1"; }
warn()   { echo -e "${RED}[警告]${RESET} $1"; }
note()   { echo -e "${CYAN}[提示]${RESET} $1"; }

# ===== 🛠 设置代理函数 =====
set_proxy() {
  echo -e "\n🌐 请选择代理类型："
  echo -e "  1) HTTP"
  echo -e "  2) SOCKS5"

  prompt "➤ 输入数字选择代理类型 [1/2]: "
  read -r PROXY_TYPE
  case $PROXY_TYPE in
    1) TYPE="http";;
    2) TYPE="socks5";;
    *) warn "无效选择"; return;;
  esac

  prompt "🌍 请输入代理地址（默认: 127.0.0.1）: "
  read -r HOST
  HOST=${HOST:-127.0.0.1}

  prompt "🔌 请输入端口号（默认: 7890）: "
  read -r PORT
  PORT=${PORT:-7890}

  PROXY_URL="$TYPE://$HOST:$PORT"

  # 🧩 设置系统级环境变量
  echo "http_proxy=\"$PROXY_URL\"
https_proxy=\"$PROXY_URL\"
HTTP_PROXY=\"$PROXY_URL\"
HTTPS_PROXY=\"$PROXY_URL\"
no_proxy=\"localhost,127.0.0.1\"
NO_PROXY=\"localhost,127.0.0.1\"" | tee /etc/environment >/dev/null
  info "已设置系统环境代理：$PROXY_URL"

  # 🐳 设置 Docker Daemon 代理
  mkdir -p /etc/systemd/system/docker.service.d
  cat <<EOF > /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=$PROXY_URL"
Environment="HTTPS_PROXY=$PROXY_URL"
Environment="NO_PROXY=localhost,127.0.0.1"
EOF

  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl restart docker
  info "Docker 守护进程代理已设置"

  # 🐳 设置 Docker 客户端代理
  mkdir -p ~/.docker
  cat <<EOF > ~/.docker/config.json
{
  "proxies": {
    "default": {
      "httpProxy": "$PROXY_URL",
      "httpsProxy": "$PROXY_URL",
      "noProxy": "localhost,127.0.0.1"
    }
  }
}
EOF
  info "Docker 客户端代理已设置：~/.docker/config.json"
}

# ===== ❌ 取消所有代理函数 =====
unset_proxy() {
  # 系统环境变量
  sed -i '/http_proxy/d;/https_proxy/d;/HTTP_PROXY/d;/HTTPS_PROXY/d;/no_proxy/d;/NO_PROXY/d' /etc/environment
  info "已清除系统环境代理"

  # Docker Daemon
  rm -f /etc/systemd/system/docker.service.d/http-proxy.conf
  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl restart docker
  info "已清除 Docker 守护进程代理"

  # Docker 客户端
  if [ -f ~/.docker/config.json ]; then
    jq 'del(.proxies)' ~/.docker/config.json > ~/.docker/config.tmp && mv ~/.docker/config.tmp ~/.docker/config.json
    info "已清除 Docker 客户端代理"
  else
    warn "~/.docker/config.json 不存在，跳过"
  fi
}

# ===== 📋 菜单函数 =====
show_menu() {
  echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}💡 请选择操作：${RESET}\n"
  echo -e "  ${CYAN}[1]${RESET} 🌐 设置代理"
  echo -e "  ${CYAN}[2]${RESET} 🧹 取消代理"
  echo -e "  ${CYAN}[3]${RESET} ❌ 退出程序"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# ===== 🚀 主程序 =====
while true; do
  show_menu
  prompt "➤ 输入编号 [1-3]: "
  read -r CHOICE
  echo ""
  case $CHOICE in
    1) set_proxy; break ;;
    2) unset_proxy; break ;;
    3) echo -e "${GREEN}👋 再见！${RESET}"; break ;;
    *) warn "无效输入，请输入 1 ~ 3" ;;
  esac
done

