#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

log_section "fcitx5 安装"
sudo apt install -y fcitx5 fcitx5-chinese-addons fcitx5-rime librime-plugin-lua

log_section "fcitx5 环境变量"
sudo mkdir -p /etc/environment.d
printf 'INPUT_METHOD=fcitx\nGTK_IM_MODULE=fcitx\nQT_IM_MODULE=fcitx\nXMODIFIERS=@im=fcitx\n' \
    | sudo tee /etc/environment.d/fcitx5.conf > /dev/null

log_section "oh-my-rime 配置"
git_clone_or_skip https://github.com/Mintimate/oh-my-rime "$HOME/.local/share/fcitx5/rime"

log_section "fcitx5 mint 主题"
git_clone_or_skip https://github.com/witt-bit/fcitx5-theme-mint.git /tmp/fcitx5-theme-mint
bash /tmp/fcitx5-theme-mint/install.sh

log_success "fcitx5 完成"
