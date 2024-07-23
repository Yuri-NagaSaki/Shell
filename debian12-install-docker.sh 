#!/bin/bash

# 更新系统包
apt update
apt upgrade -y

# 安装必要的包
apt install -y curl vim wget gnupg dpkg apt-transport-https lsb-release ca-certificates

# 添加 Docker 的 GPG 密钥
curl -sSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-ce.gpg

# 添加 Docker 的 APT 源
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-ce.gpg] https://download.docker.com/linux/debian $(lsb_release -sc) stable" > /etc/apt/sources.list.d/docker.list

# 更新 APT 索引并安装 Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 安装 Docker Compose
curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-Linux-x86_64 -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 配置 Docker 守护进程
cat > /etc/docker/daemon.json << EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "20m",
        "max-file": "3"
    },
    "ipv6": true,
    "fixed-cidr-v6": "fd00:dead:beef:c0::/80",
    "experimental": true,
    "ip6tables": true
}
EOF

# 重启 Docker 服务
systemctl restart docker

# 显示 Docker 版本
docker -v