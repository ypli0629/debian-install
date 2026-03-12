#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

log_section "安装依赖"
sudo apt install -y flameshot gnome-tweaks gnome-shell-extension-manager gnome-shell-extensions

# ── 检查 GNOME 桌面环境 ───────────────────────────────────
# gsettings 依赖 DBUS session，在 TTY/SSH 无桌面环境下会失败
if ! gsettings list-schemas &>/dev/null 2>&1; then
    log_info "未检测到 GNOME session（DBUS 不可用），跳过快捷键配置"
    log_info "请在桌面环境登录后手动重新运行此脚本：bash scripts/gnome.sh"
    exit 0
fi

log_section "GNOME 工作区快捷键"
for i in $(seq 1 9); do
    gsettings set org.gnome.shell.keybindings switch-to-application-${i} '[]'
    gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-${i} "['<Shift><Super>${i}']"
    gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-${i} "['<Super>${i}']"
done

log_section "GNOME 窗口快捷键"
gsettings set org.gnome.desktop.wm.keybindings toggle-fullscreen "['<Super>f']"
gsettings set org.gnome.desktop.wm.keybindings close "['<Super>q']"
gsettings set org.gnome.shell.keybindings toggle-application-view "['<Shift><Super>d']"

log_section "GNOME 自定义快捷键"
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
    "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', \
      '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/']"

gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'flameshot'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'flameshot gui'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Alt>F1'

gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ name 'gnome-terminal'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ command 'gnome-terminal'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ binding '<Super>Return'

log_section "启用 User Themes 扩展"
# MacTahoe 主题必须依赖此扩展才能在 GNOME 中生效
if gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com 2>/dev/null; then
    log_success "User Themes 扩展已启用"
else
    log_info "User Themes 扩展启用失败，请在扩展管理器中手动启用后应用 MacTahoe 主题"
fi

log_success "GNOME 快捷键配置完成"
