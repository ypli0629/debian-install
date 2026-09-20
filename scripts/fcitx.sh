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
git_clone_or_skip https://github.com/Mintimate/oh-my-rime "$HOME/.local/share/fcitx5/rime" \
    || record_failure "oh-my-rime 配置" "克隆失败或目标目录非 git 仓库"

log_section "fcitx5 mint 主题"
MINT_SRC="$HOME/.local/share/themes-src/fcitx5-theme-mint"
mkdir -p "$HOME/.local/share/themes-src"
# 克隆失败则不进入安装分支，避免执行来源不可信的残留 install.sh 或重复记录失败
if ! git_clone_or_skip https://github.com/witt-bit/fcitx5-theme-mint.git "$MINT_SRC"; then
    record_failure "fcitx5 mint 主题" "克隆失败或目标目录非 git 仓库"
# 检查主题是否已安装（安装到 ~/.local/share/fcitx5/themes/）
elif ls -d "$HOME/.local/share/fcitx5/themes/Mint"* &>/dev/null 2>&1; then
    log_info "fcitx5 mint 主题已安装，跳过"
elif [[ -f "$MINT_SRC/install.sh" ]]; then
    if bash "$MINT_SRC/install.sh"; then
        log_success "fcitx5 mint 主题安装完成"
    else
        record_failure "fcitx5 mint 主题" "install.sh 执行失败"
    fi
else
    record_failure "fcitx5 mint 主题" "未找到 $MINT_SRC/install.sh"
fi

log_success "fcitx5 完成"
finish || exit 1
