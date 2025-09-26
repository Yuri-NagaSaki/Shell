#!/usr/bin/env bash
# 自动安装 zsh + oh-my-zsh + 常用插件，并设置为默认 shell
set -e

echo "==== Installing zsh and dependencies ===="
if ! command -v zsh >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y zsh git curl wget fzf
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y zsh git curl wget fzf
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y zsh git curl wget fzf
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm zsh git curl wget fzf
    else
        echo "Unsupported package manager. Please install zsh, git, curl, wget, fzf manually."
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

echo "==== Installing custom theme (haoomz) ===="
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
if [ ! -f "$ZSH_CUSTOM/themes/haoomz.zsh-theme" ]; then
    mkdir -p "$ZSH_CUSTOM/themes"
    wget -O "$ZSH_CUSTOM/themes/haoomz.zsh-theme" https://cdn.haoyep.com/gh/leegical/Blog_img/zsh/haoomz.zsh-theme
    echo "haoomz theme installed."
else
    echo "haoomz theme already installed."
fi

echo "==== Installing zsh plugins ===="

# zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
    echo "zsh-autosuggestions installed."
else
    echo "zsh-autosuggestions already installed."
fi

# zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
    echo "zsh-syntax-highlighting installed."
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

# 设置主题为 haoomz
ZSH_THEME="haoomz"

# 插件配置
plugins=(
  git
  z
  zsh-autosuggestions
  zsh-syntax-highlighting
  extract
)

source $ZSH/oh-my-zsh.sh

# fzf 配置
if command -v fzf >/dev/null 2>&1; then
    # 检测 fzf 安装路径并设置 FZF_BASE
    if [ -d "/usr/share/fzf" ]; then
        # Ubuntu/Debian 系统的 fzf 路径
        export FZF_BASE="/usr/share/fzf"
    elif [ -d "/usr/share/doc/fzf" ]; then
        # 某些 Debian 系统的路径
        export FZF_BASE="/usr/share/doc/fzf"
    elif [ -d "/opt/homebrew/opt/fzf" ]; then
        # macOS Homebrew ARM 路径
        export FZF_BASE="/opt/homebrew/opt/fzf"
    elif [ -d "/usr/local/opt/fzf" ]; then
        # macOS Homebrew Intel 路径
        export FZF_BASE="/usr/local/opt/fzf"
    elif [ -d "$HOME/.fzf" ]; then
        # 手动安装到用户目录
        export FZF_BASE="$HOME/.fzf"
    elif [ -d "/usr/share/fzf-git" ]; then
        # Arch Linux 路径
        export FZF_BASE="/usr/share/fzf-git"
    fi
    
    # 使用 fd 作为默认搜索命令（如果可用）
    if command -v fd >/dev/null 2>&1; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    fi
    
    # 手动加载 fzf 的快捷键和补全
    if [ -f "$FZF_BASE/shell/completion.zsh" ]; then
        source "$FZF_BASE/shell/completion.zsh"
    fi
    if [ -f "$FZF_BASE/shell/key-bindings.zsh" ]; then
        source "$FZF_BASE/shell/key-bindings.zsh"
    fi
    
    # 备用方案：如果系统安装了 fzf，尝试加载标准路径
    [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
    [ -f /usr/share/fzf/shell/key-bindings.zsh ] && source /usr/share/fzf/shell/key-bindings.zsh
    [ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh
    
    # 设置 fzf 颜色主题
    export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
fi

# zsh-autosuggestions 配置
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# 自定义别名
alias ll='ls -lah --color=auto'
alias la='ls -la --color=auto'
alias l='ls -l --color=auto'
alias gs='git status'
alias gp='git pull'
alias gd='git diff'
alias ga='git add'
alias gc='git commit'
alias gl='git log --oneline'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# 历史记录配置
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

# 其他有用的设置
setopt AUTO_CD              # 输入目录名自动 cd
setopt CORRECT              # 命令纠错
setopt GLOB_DOTS            # 匹配隐藏文件

# 自定义函数
mcd() {
    mkdir -p "$1" && cd "$1"
}

# 快速搜索历史命令
fh() {
    print -z $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed 's/ *[0-9]* *//')
}

# 快速进入目录
fd() {
    local dir
    dir=$(find ${1:-.} -path '*/\.*' -prune -o -type d -print 2> /dev/null | fzf +m) &&
    cd "$dir"
}

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

echo ""
echo "==== 安装完成! ===="
echo "✅ 已安装的插件："
echo "   - git (Git 集成)"
echo "   - z (智能目录跳转)"
echo "   - zsh-autosuggestions (命令自动补全)"
echo "   - zsh-syntax-highlighting (语法高亮)"
echo "   - fzf (模糊搜索)"
echo "   - extract (解压缩工具)"
echo ""
echo "✅ 已安装的主题："
echo "   - haoomz (自定义主题)"
echo ""
echo "🔧 额外功能："
echo "   - 优化的历史记录配置"
echo "   - 实用的别名和函数"
echo "   - fzf 快捷键集成"
echo ""
echo "📝 使用说明："
echo "   - fh: 模糊搜索历史命令"
echo "   - fd: 模糊搜索并进入目录"
echo "   - mcd <dir>: 创建并进入目录"
echo "   - extract <file>: 解压各种格式的压缩文件"
echo ""

# 直接进入 zsh 会话
exec zsh -l

