#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

check_sudo

log_section "fcitx5 安装"
sudo apt install -y fcitx5 fcitx5-chinese-addons fcitx5-rime librime-plugin-lua

log_section "fcitx5 环境变量"
# /etc/environment 由 PAM pam_env.so 读取，适用于所有 session（X11/Wayland/TTY）
# /etc/environment.d/ 仅对 systemd --user 服务生效，GDM 走 PAM 不读它
for _var in "INPUT_METHOD=fcitx" "GTK_IM_MODULE=fcitx" "QT_IM_MODULE=fcitx" "XMODIFIERS=@im=fcitx"; do
    _key="${_var%%=*}"
    if sudo grep -q "^${_key}=" /etc/environment 2>/dev/null; then
        log_info "${_key} 已存在于 /etc/environment，跳过"
    else
        echo "$_var" | sudo tee -a /etc/environment > /dev/null
        log_success "已写入 /etc/environment：$_var"
    fi
done
unset _var _key

log_section "oh-my-rime 配置"
git_clone_or_skip https://github.com/Mintimate/oh-my-rime "$HOME/.local/share/fcitx5/rime"

log_section "fcitx5 mint 主题"
MINT_SRC="$HOME/.local/share/themes-src/fcitx5-theme-mint"
mkdir -p "$HOME/.local/share/themes-src"
git_clone_or_skip https://github.com/witt-bit/fcitx5-theme-mint.git "$MINT_SRC"
# 检查主题是否已安装（安装到 ~/.local/share/fcitx5/themes/）
if ls -d "$HOME/.local/share/fcitx5/themes/Mint"* &>/dev/null 2>&1; then
    log_info "fcitx5 mint 主题已安装，跳过"
else
    bash "$MINT_SRC/install.sh"
    log_success "fcitx5 mint 主题安装完成"
fi

log_success "fcitx5 完成"
