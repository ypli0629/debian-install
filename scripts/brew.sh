#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

log_section "Homebrew"

if command -v brew &>/dev/null; then
    log_info "Homebrew 已安装，跳过"
else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo 'PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"' \
    | sudo tee /etc/environment.d/brew.conf > /dev/null
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

log_section "Homebrew 软件包"
brew install --cask font-sauce-code-pro-nerd-font
brew install gcc go rustup node pnpm yarn neovim bear

log_success "brew 完成"
