#!/bin/bash

# Script to install and configure zsh with Oh My Zsh on Ubuntu/Debian
# Author: Created based on user requirements
# Date: April 7, 2025

# Exit on error
set -e

echo "==== Starting ZSH Installation and Configuration ===="

# Check if running as root and warn user
if [ "$(id -u)" = 0 ]; then
    echo "WARNING: You are running this script as root. It's recommended to run it as a regular user with sudo privileges."
    read -p "Continue as root? (y/n): " choice
    if [ "$choice" != "y" ]; then
        exit 1
    fi
fi

echo "==== Updating system packages ===="
apt update && sudo apt upgrade -y

echo "==== Installing required packages ===="
apt install zsh git curl vim fzf duf sudo -y

# Backup existing .zshrc if it exists
if [ -f "$HOME/.zshrc" ]; then
    echo "==== Backing up existing .zshrc ===="
    cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d%H%M%S)"
fi

# Check if Oh My Zsh is already installed
if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "==== Oh My Zsh is already installed, skipping installation ===="
else
    echo "==== Installing Oh My Zsh ===="
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install plugins
echo "==== Installing zsh plugins ===="
# Check if zsh-autosuggestions is already installed
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
else
    echo "zsh-autosuggestions is already installed"
fi

# Check if zsh-syntax-highlighting is already installed
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
else
    echo "zsh-syntax-highlighting is already installed"
fi

# Install custom theme
echo "==== Installing haoomz theme ===="
wget -O ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/haoomz.zsh-theme https://cdn.haoyep.com/gh/leegical/Blog_img/zsh/haoomz.zsh-theme

# Create .zshrc with the specific configuration
echo "==== Creating .zshrc configuration ===="
cat > "$HOME/.zshrc" << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="haoomz"
plugins=(git z zsh-autosuggestions fzf zsh-syntax-highlighting extract)
source $ZSH/oh-my-zsh.sh
export LANG=en_US.UTF-8
export LANGUAGE="en_US"
export LC_ALL=en_US.UTF-8
export LS_OPTIONS='--color=auto'
# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi
alias vi="vim"
EOF

echo "==== Configuration complete! ===="
echo "To use zsh now, run: source ~/.zshrc"
echo "To make zsh your default shell, run: chsh -s $(which zsh)"

# Prompt user if they want to switch to zsh now
read -p "Do you want to switch to zsh now? (y/n): " switch_now
if [ "$switch_now" = "y" ]; then
    echo "Switching to zsh..."
    exec zsh -l
else
    echo "You can switch to zsh later by running: exec zsh"
fi
