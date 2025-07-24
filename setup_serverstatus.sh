#!/bin/bash

# 仅下载 install-rust_serverstatus.sh
curl -sS -O https://raw.githubusercontent.com/Yuri-NagaSaki/Shell/refs/heads/main/install_rust-serverstatus.sh
chmod +x install-rust_serverstatus.sh

# 下载并执行 serverstatus_manager.sh
curl -sS -O https://raw.githubusercontent.com/Yuri-NagaSaki/Shell/refs/heads/main/serverstatus_manager.sh
chmod +x serverstatus_manager.sh
./serverstatus_manager.sh
