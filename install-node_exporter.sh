# 获取 Prometheus 最新版本
github_project="prometheus/node_exporter"
tag=$(wget -qO- -t1 -T2 "https://api.github.com/repos/${github_project}/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
echo ${tag}
echo ${tag#*v}

wget https://gh-proxy.catcat.blog/github.com/prometheus/node_exporter/releases/download/${tag}/node_exporter-${tag#*v}.linux-amd64.tar.gz && \
tar xvfz node_exporter-*.tar.gz && \
rm node_exporter-*.tar.gz
sudo mv node_exporter-*.linux-amd64/node_exporter /usr/local/bin
rm -r node_exporter-*.linux-amd64*

sudo useradd -rs /bin/false node_exporter

sudo cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
sudo systemctl status node_exporter
 
