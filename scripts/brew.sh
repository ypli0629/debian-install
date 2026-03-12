#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

check_sudo

log_section "Homebrew"

if command -v brew &>/dev/null; then
    log_info "Homebrew 已安装，跳过"
else
    NONINTERACTIVE=1 /bin/bash -c "$(gh_curl https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [[ ! -f /etc/environment.d/brew.conf ]]; then
    echo 'PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"' \
        | sudo tee /etc/environment.d/brew.conf > /dev/null
else
    log_info "brew.conf 已存在，跳过"
fi

BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"
if [[ -x "$BREW_BIN" ]]; then
    eval "$($BREW_BIN shellenv)"
else
    log_error "brew 可执行文件未找到：$BREW_BIN" fatal
fi

log_section "Homebrew 软件包"
brew install --cask font-sauce-code-pro-nerd-font
brew install gcc go rustup node pnpm yarn neovim bear fzf mycli \
    lazydocker jq mkcert xh

log_success "brew 完成"
