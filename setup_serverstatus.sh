#!/bin/bash

# 仅下载 install-rust_serverstatus.sh
curl -sS -O https://cdn.lirica.cn/Bash/install-rust_serverstatus.sh
chmod +x install-rust_serverstatus.sh

# 下载并执行 serverstatus_manager.sh
curl -sS -O https://cdn.lirica.cn/Bash/serverstatus_manager.sh
chmod +x serverstatus_manager.sh
./serverstatus_manager.sh
