#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

check_sudo

log_section "安装依赖"
sudo apt install -y flameshot gnome-tweaks gnome-shell-extension-manager

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

CUSTOM_SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
CUSTOM_PREFIX="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"

# 读取现有自定义快捷键路径列表（gsettings 输出形如 ['...custom0/', ...] 或 []）
_existing_raw="$(gsettings get "$CUSTOM_SCHEMA" custom-keybindings 2>/dev/null || true)"
_existing_paths=()
while IFS= read -r _p; do
    [[ -n "$_p" ]] && _existing_paths+=("$_p")
done < <(printf '%s\n' "$_existing_raw" | grep -oE "'[^']*'" | tr -d "'" || true)
unset _existing_raw

# 按 name 查找已存在的绑定路径，找到则输出该路径
_find_path_by_name() {
    local want="$1" p n
    for p in "${_existing_paths[@]}"; do
        n="$(gsettings get "${CUSTOM_SCHEMA}.custom-keybinding:${p}" name 2>/dev/null || true)"
        n="${n#\'}"; n="${n%\'}"
        if [[ "$n" == "$want" ]]; then
            printf '%s\n' "$p"
            return 0
        fi
    done
    return 1
}

# 在 custom0..custom99 中选第一个未被占用的路径
_find_free_path() {
    local i cand p
    for ((i=0; i<100; i++)); do
        cand="${CUSTOM_PREFIX}custom${i}/"
        for p in "${_existing_paths[@]}"; do
            [[ "$p" == "$cand" ]] && continue 2
        done
        printf '%s\n' "$cand"
        return 0
    done
    return 1
}

log_section "GNOME 自定义快捷键"
# 保留用户已有自定义快捷键：读取现有列表并合并 flameshot / gnome-terminal 后写回（幂等）
_selected_paths=()
_selected_names=()
_selected_cmds=()
_selected_bindings=()
for _spec in "flameshot|flameshot gui|<Alt>F1" \
             "gnome-terminal|gnome-terminal|<Super>Return"; do
    IFS='|' read -r _name _cmd _binding <<< "$_spec"
    if _path="$(_find_path_by_name "$_name")"; then
        : # 复用同名已有路径
    elif _path="$(_find_free_path)"; then
        _existing_paths+=("$_path")   # 标记已占用，避免后续目标重复选择同一索引
    else
        log_error "无空闲 customN 索引，跳过：$_name"
        continue
    fi
    _selected_paths+=("$_path")
    _selected_names+=("$_name")
    _selected_cmds+=("$_cmd")
    _selected_bindings+=("$_binding")
done

# 合并现有路径与新选路径（去重、保持顺序，新路径追加在后）
_merged_paths=("${_existing_paths[@]}")
for _p in "${_selected_paths[@]}"; do
    _dup=0
    for _m in "${_merged_paths[@]}"; do
        [[ "$_m" == "$_p" ]] && { _dup=1; break; }
    done
    [[ $_dup -eq 0 ]] && _merged_paths+=("$_p")
done

_list="["
_sep=""
for _p in "${_merged_paths[@]}"; do
    [[ -z "$_p" ]] && continue
    _list+="${_sep}'${_p}'"
    _sep=", "
done
_list+="]"
gsettings set "$CUSTOM_SCHEMA" custom-keybindings "$_list"

# 写入选中路径的 name/command/binding
for _i in "${!_selected_paths[@]}"; do
    _p="${_selected_paths[$_i]}"
    gsettings set "${CUSTOM_SCHEMA}.custom-keybinding:${_p}" name "${_selected_names[$_i]}"
    gsettings set "${CUSTOM_SCHEMA}.custom-keybinding:${_p}" command "${_selected_cmds[$_i]}"
    gsettings set "${CUSTOM_SCHEMA}.custom-keybinding:${_p}" binding "${_selected_bindings[$_i]}"
done
unset _p

log_success "GNOME 快捷键配置完成"
