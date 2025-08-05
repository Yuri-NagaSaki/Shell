#!/bin/bash

set -e

ENV_FILE="/etc/environment"
DOCKER_PROXY_DIR="/etc/systemd/system/docker.service.d"
DOCKER_PROXY_FILE="${DOCKER_PROXY_DIR}/http-proxy.conf"

# ===== 样式定义 =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

success() { echo -e "${GREEN}✔ $1${RESET}"; }
info()    { echo -e "${BLUE}ℹ $1${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $1${RESET}"; }
error()   { echo -e "${RED}✘ $1${RESET}"; }
prompt()  { echo -ne "${CYAN}➤ $1${RESET}"; }

# ===== 设置代理 =====
set_proxy() {
  echo -e "\n${BOLD}🌐 设置系统代理${RESET}"

  echo -e "${BOLD}请选择代理类型：${RESET}"
  echo -e "  ${CYAN}[1]${RESET} HTTP"
  echo -e "  ${CYAN}[2]${RESET} SOCKS5"
  while true; do
    prompt "输入编号 [1-2]: "
    read -r PROXY_CHOICE
    case $PROXY_CHOICE in
      1) PROXY_TYPE="http"; break ;;
      2) PROXY_TYPE="socks5"; break ;;
      *) warn "请输入有效编号 1 或 2" ;;
    esac
  done

  prompt "请输入代理地址（例如 172.18.6.71）: "
  read -r PROXY_IP
  prompt "请输入代理端口（例如 7890）: "
  read -r PROXY_PORT

  PROXY_URI="${PROXY_TYPE}://${PROXY_IP}:${PROXY_PORT}"
  info "设置代理地址为：${PROXY_URI}"

  # 清除旧环境变量
  sudo sed -i '/http_proxy=/d' "$ENV_FILE" || true
  sudo sed -i '/https_proxy=/d' "$ENV_FILE" || true
  sudo sed -i '/ftp_proxy=/d' "$ENV_FILE" || true
  sudo sed -i '/no_proxy=/d' "$ENV_FILE" || true

  # 写入新环境变量
  {
    echo "http_proxy=\"$PROXY_URI\""
    echo "https_proxy=\"$PROXY_URI\""
    echo "ftp_proxy=\"$PROXY_URI\""
    echo "no_proxy=\"localhost,127.0.0.1,::1\""
  } | sudo tee -a "$ENV_FILE" > /dev/null

  success "系统环境变量代理已设置"

  # Git 配置（可选）
  prompt "是否为 git 设置代理？(y/n): "
  read -r SET_GIT
  if [[ "$SET_GIT" =~ ^[Yy]$ ]]; then
    git config --global http.proxy "$PROXY_URI"
    git config --global https.proxy "$PROXY_URI"
    success "已设置 git 代理"
  fi

  # Docker 配置（可选）
  prompt "是否为 Docker 设置代理？(y/n): "
  read -r SET_DOCKER
  if [[ "$SET_DOCKER" =~ ^[Yy]$ ]]; then
    sudo mkdir -p "$DOCKER_PROXY_DIR"
    sudo tee "$DOCKER_PROXY_FILE" > /dev/null <<EOF
[Service]
Environment="HTTP_PROXY=$PROXY_URI"
Environment="HTTPS_PROXY=$PROXY_URI"
EOF
    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    success "已设置 Docker 代理"
  fi

  echo
  success "所有代理配置完成 🎉"
  info "请重新登录终端或重启系统以完全生效"
}

# ===== 取消代理 =====
unset_proxy() {
  echo -e "\n${BOLD}🧹 正在取消代理设置${RESET}"

  sudo sed -i '/http_proxy=/d' "$ENV_FILE" || true
  sudo sed -i '/https_proxy=/d' "$ENV_FILE" || true
  sudo sed -i '/ftp_proxy=/d' "$ENV_FILE" || true
  sudo sed -i '/no_proxy=/d' "$ENV_FILE" || true
  success "已清除系统环境变量代理"

  git config --global --unset http.proxy || true
  git config --global --unset https.proxy || true
  success "已清除 git 代理设置"

  if [ -f "$DOCKER_PROXY_FILE" ]; then
    sudo rm -f "$DOCKER_PROXY_FILE"
    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    success "已清除 Docker 代理设置"
  else
    info "未检测到 Docker 代理配置，无需清理"
  fi

  echo
  success "所有代理已取消 🧽"
}

# ===== 菜单展示 =====
show_menu() {
  echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}💡 请选择操作：${RESET}\n"
  echo -e "  ${CYAN}[1]${RESET} 🌐 设置代理"
  echo -e "  ${CYAN}[2]${RESET} 🧹 取消代理"
  echo -e "  ${CYAN}[3]${RESET} ❌ 退出程序"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# ===== 主入口 =====
while true; do
  show_menu
  prompt "输入编号 [1-3]: "
  read -r CHOICE
  echo ""
  case $CHOICE in
    1) set_proxy; break ;;
    2) unset_proxy; break ;;
    3) echo -e "${GREEN}👋 再见！${RESET}"; break ;;
    *) warn "请输入有效编号 1 ~ 3" ;;
  esac
done
