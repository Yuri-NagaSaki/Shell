#!/usr/bin/env bash
# 自动安装 zsh + oh-my-zsh + 常用插件，并设置为默认 shell

set -e

echo "==== Installing zsh ===="
if ! command -v zsh >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y zsh git curl
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y zsh git curl
    else
        echo "Unsupported package manager. Please install zsh manually."
        exit 1
    fi
else
    echo "zsh already installed."
fi

echo "==== Installing oh-my-zsh ===="
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "oh-my-zsh already installed."
fi

echo "==== Installing zsh plugins ===="
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

# zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
else
    echo "zsh-autosuggestions already installed."
fi

# zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
else
    echo "zsh-syntax-highlighting already installed."
fi

echo "==== Configuring .zshrc ===="
if [ -f "$HOME/.zshrc" ]; then
    cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%s)"
    echo "Backed up existing .zshrc"
fi

cat > "$HOME/.zshrc" << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# 自定义别名
alias ll='ls -lah --color=auto'
alias gs='git status'
alias gp='git pull'
alias ..='cd ..'
alias ...='cd ../..'
EOF

echo "==== .zshrc configured successfully ===="

# ==============================
# 设置默认 shell 为 zsh
# ==============================
echo "==== Setting zsh as the default shell ===="

CURRENT_SHELL=$(getent passwd $USER | cut -d: -f7)
ZSH_PATH=$(which zsh)

if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
    if chsh -s "$ZSH_PATH"; then
        echo "✅ Default shell changed to zsh."
        echo "⚠️ 请注销并重新登录后生效。"
    else
        echo "❌ Failed to change default shell. 请手动运行:"
        echo "   sudo chsh -s $(which zsh) $(whoami)"
    fi
else
    echo "ℹ️ 已经是 zsh，无需修改。"
fi

echo "==== All done! ===="

# 直接进入 zsh 会话
exec zsh -l

