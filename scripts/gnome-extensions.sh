#!/bin/bash
# GNOME Shell 扩展安装：
#   1) 从 extensions.gnome.org 按 UUID 批量安装；
#   2) 安装本仓库自带的 xbox 扩展（make link）。
# 幂等：已存在的扩展目录会跳过。
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

check_sudo

# ── 依赖 ──────────────────────────────────────────────────
log_section "安装依赖"
sudo apt-get install -y unzip python3 libglib2.0-bin

# ── 环境检查 ──────────────────────────────────────────────
if ! command -v gnome-shell &>/dev/null; then
    log_error "未找到 gnome-shell，跳过 GNOME 扩展安装" fatal
fi

SHELL_VERSION="$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1)"
SHELL_VERSION="${SHELL_VERSION:-48}"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
mkdir -p "$EXT_DIR"

# 需要在 extensions.gnome.org 上安装的扩展（UUID，区分大小写）
EXTENSIONS=(
    "appindicatorsupport@rgcjonas.gmail.com"
    "auto-move-windows@gnome-shell-extensions.gcampax.github.com"
    "blur-my-shell@aunetx"
    "burn-my-windows@schneegans.github.com"
    "caffeine@patapon.info"
    "clipboard-indicator@tudmotu.com"
    "CoverflowAltTab@palatis.blogspot.com"
    "dash-to-dock@micxgx.gmail.com"
    "ddterm@amezin.github.com"
    "ding@rastersoft.com"
    "drive-menu@gnome-shell-extensions.gcampax.github.com"
    "kimpanel@kde.org"
    "runcat@kolesnikov.se"
    "tweaks-system-menu@extensions.gnome-shell.fifi.org"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
    "Vitals@CoreCoding.com"
)

# ── 单个扩展安装 ──────────────────────────────────────────
install_egon_extension() {
    local uuid="$1"
    local dest="$EXT_DIR/$uuid"
    if [[ -d "$dest" ]]; then
        log_info "已安装，跳过：$uuid"
        return 0
    fi

    local info url
    if ! info="$(gh_curl "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${SHELL_VERSION}")"; then
        log_error "获取扩展信息失败：$uuid"
        return 1
    fi
    url="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("download_url",""))' <<<"$info" 2>/dev/null || true)"
    if [[ -z "$url" ]]; then
        log_error "扩展没有适配 GNOME ${SHELL_VERSION} 的版本：$uuid"
        return 1
    fi

    local tmp_zip="/tmp/gnome-ext-${uuid}.zip"
    if gh_wget "https://extensions.gnome.org${url}" "$tmp_zip"; then
        mkdir -p "$dest"
        unzip -q -o "$tmp_zip" -d "$dest"
        rm -f "$tmp_zip"
        log_success "已安装：$uuid"
    else
        log_error "下载失败：$uuid"
        return 1
    fi
}

log_section "安装 extensions.gnome.org 扩展（GNOME ${SHELL_VERSION}）"
for uuid in "${EXTENSIONS[@]}"; do
    install_egon_extension "$uuid" || record_failure "GNOME 扩展 $uuid"
done

# ── 本仓库 xbox 扩展 ──────────────────────────────────────
log_section "安装 xbox 扩展"
XBOX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../xbox" && pwd)"
if [[ -f "$XBOX_DIR/metadata.json" ]]; then
    make -C "$XBOX_DIR" link \
        && log_success "xbox 已链接到 $EXT_DIR/xbox" \
        || record_failure "xbox 扩展" "make link 失败"
else
    record_failure "xbox 扩展" "未找到 $XBOX_DIR/metadata.json"
fi

# ── 启用 ──────────────────────────────────────────────────
log_section "启用扩展"
if gsettings list-schemas &>/dev/null 2>&1; then
    for uuid in "${EXTENSIONS[@]}" xbox; do
        gnome-extensions enable "$uuid" 2>/dev/null || true
    done
    log_info "已尝试启用扩展（新安装的扩展需注销重登后生效）"
else
    log_info "未检测到 GNOME session，跳过启用；登录桌面后执行：gnome-extensions enable <uuid>"
fi

log_success "GNOME 扩展安装完成"
