#!/bin/bash
# =========================================================
#  install_qbt.sh  –  以 root 身份初始化并启动 qBittorrent
# =========================================================
set -e

# 1. 必须以 root 运行
if [[ $EUID -ne 0 ]]; then
    echo "请用 root 身份运行：sudo $0"
    exit 1
fi

# 2. 创建目录结构
YAML_ROOT="/root/docker-yaml"
QBT_DIR="${YAML_ROOT}/qbittorrent"
mkdir -p "$QBT_DIR"

# 3. 写入 docker-compose.yaml
cat > "${QBT_DIR}/docker-compose.yaml" <<'EOF'
version: '3'

services:
  qbittorrent:
    image: linuxserver/qbittorrent:5.1.0
    container_name: qbittorrent
    network_mode: host
    environment:
      - PUID=0
      - PGID=0
      - TZ=Asia/Shanghai
      - WEBUI_PORT=8181
      - TORRENTING_PORT=25655
    volumes:
      - ./config:/config
      - /hdd/media:/media
    restart: unless-stopped
EOF

# 4. 启动
cd "$QBT_DIR"
docker compose up -d

echo "------------------------------------------------"
echo "qBittorrent 已启动，WebUI 端口：8181"
echo "配置文件位于：${QBT_DIR}/config"
echo "下载文件将映射到宿主机 /hdd/media"
echo "------------------------------------------------"
