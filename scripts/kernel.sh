#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

check_sudo

GRUB_CFG="/boot/grub/grub.cfg"
GRUB_DEFAULT_FILE="/etc/default/grub"

# ── 探测 kernel.ubuntu.com 可用协议 ───────────────────────
# 部分 Debian 环境下 CA 证书不信任 Canonical，TLS 握手失败，回退 HTTP
if curl -fsSL --connect-timeout 10 "https://kernel.ubuntu.com/mainline/" -o /dev/null 2>/dev/null; then
    MAINLINE_BASE="https://kernel.ubuntu.com/mainline"
else
    log_info "HTTPS 连接 kernel.ubuntu.com 失败，回退使用 HTTP"
    MAINLINE_BASE="http://kernel.ubuntu.com/mainline"
fi

# ── 查找最新 6.6.x mainline 版本 ─────────────────────────
log_section "查找 Ubuntu Mainline 6.6 最新版本"

LATEST_TAG=$(curl -fsSL "${MAINLINE_BASE}/" \
    | grep -oP 'v6\.6\.\d+(?!-rc)/' \
    | sort -V | tail -1 | tr -d '/')

[[ -z "$LATEST_TAG" ]] && log_error "无法获取 6.6.x 版本列表" fatal
log_info "最新版本：$LATEST_TAG"

# ── 幂等性：已安装同版本则跳过下载和安装 ──────────────────
# mainline 内核包名格式：linux-image-unsigned-6.6.87-060687-generic
_kernel_installed() {
    dpkg-query -W "linux-image-unsigned-${LATEST_TAG#v}*" 2>/dev/null \
        | grep -qv '^$'
}

if _kernel_installed; then
    log_info "内核 ${LATEST_TAG} 已安装，跳过下载安装"
else
    PKG_PAGE_URL="${MAINLINE_BASE}/${LATEST_TAG}/amd64/"

    # ── 获取 .deb 文件列表 ────────────────────────────────────
    log_section "获取安装包列表"

    PKG_HTML=$(curl -fsSL "$PKG_PAGE_URL")

    # 需要的四个包：all headers、amd64 headers、modules、image-unsigned
    mapfile -t DEB_FILES < <(echo "$PKG_HTML" \
        | grep -oP 'linux-(?:headers-[^"]+_all|headers-[^"]+_amd64|modules-[^"]+_amd64|image-unsigned-[^"]+_amd64)\.deb' \
        | grep -v 'lowlatency\|snapdragon' \
        | sort -u)

    [[ ${#DEB_FILES[@]} -eq 0 ]] && log_error "未找到任何 .deb 包" fatal

    for f in "${DEB_FILES[@]}"; do
        log_info "  $f"
    done

    # ── 下载 ─────────────────────────────────────────────────
    log_section "下载安装包"

    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT

    for deb in "${DEB_FILES[@]}"; do
        log_info "下载：$deb"
        curl -fsSL --progress-bar "${PKG_PAGE_URL}${deb}" -o "${TMP_DIR}/${deb}"
    done

    # ── 安装 ─────────────────────────────────────────────────
    log_section "安装内核"
    sudo dpkg -i "${TMP_DIR}"/*.deb

    # ── 锁定，防止 apt 干预 ───────────────────────────────────
    # 从文件名提取包名（去掉版本和架构后缀）
    for deb in "${DEB_FILES[@]}"; do
        PKG_NAME=$(echo "$deb" | grep -oP '^[^_]+')
        sudo apt-mark hold "$PKG_NAME" 2>/dev/null || true
    done
    log_success "已锁定所有 mainline 包（apt-mark hold）"
fi

# ── 获取已安装的内核版本（新装或已有均适用）────────────────
log_section "确认内核版本"

# mainline 内核版本格式：6.6.87-060687-generic
VMLINUZ=$(ls -1 /boot/vmlinuz-6.6.*-generic 2>/dev/null | sort -V | tail -1)
[[ -z "$VMLINUZ" ]] && log_error "找不到 /boot/vmlinuz-6.6.*-generic" fatal
KERNEL_VER=$(basename "$VMLINUZ" | sed 's/^vmlinuz-//')
log_info "安装的内核版本：$KERNEL_VER"

# ── 生成 grub.cfg ─────────────────────────────────────────
log_section "生成 GRUB 配置"
sudo update-grub 2>/dev/null

# ── 读取子菜单标题并验证入口 ──────────────────────────────
ENTRY_TITLE="Debian GNU/Linux, with Linux ${KERNEL_VER}"

if ! grep -qF "$ENTRY_TITLE" "$GRUB_CFG"; then
    log_error "grub.cfg 中未找到入口：$ENTRY_TITLE" fatal
fi

# 解析 submenu 标题，并校验解析结果非空
SUBMENU_TITLE=$(grep -m1 "^submenu " "$GRUB_CFG" \
    | sed "s/submenu '\\([^']*\\)'.*/\\1/")
if [[ -z "$SUBMENU_TITLE" ]]; then
    log_error "无法解析 grub.cfg 中的 submenu 标题，请手动设置 GRUB_DEFAULT" fatal
fi

GRUB_DEFAULT_VAL="${SUBMENU_TITLE}>${ENTRY_TITLE}"
log_info "GRUB_DEFAULT → $GRUB_DEFAULT_VAL"

# ── 写入 /etc/default/grub ────────────────────────────────
log_section "配置 /etc/default/grub"
sudo cp "$GRUB_DEFAULT_FILE" "${GRUB_DEFAULT_FILE}.bak"
sudo sed -i "s|^GRUB_DEFAULT=.*|GRUB_DEFAULT=\"${GRUB_DEFAULT_VAL}\"|" "$GRUB_DEFAULT_FILE"
sudo sed -i 's|^GRUB_SAVEDEFAULT=.*|# GRUB_SAVEDEFAULT=|' "$GRUB_DEFAULT_FILE"
sudo update-grub 2>/dev/null
log_success "GRUB 已更新，默认引导 Linux ${KERNEL_VER}"

# ── 安装后钩子：重新运行脚本后自动更新 GRUB_DEFAULT ───────
log_section "添加内核安装后钩子"

sudo tee /etc/kernel/postinst.d/zz-prefer-mainline-66-kernel > /dev/null <<'HOOK'
#!/bin/bash
# 当新的 6.6.x mainline 内核安装时，自动更新 GRUB_DEFAULT
KERNEL_VERSION="$1"
GRUB_DEFAULT_FILE="/etc/default/grub"
GRUB_CFG="/boot/grub/grub.cfg"

# mainline 格式：6.6.x-06066x-generic
[[ "$KERNEL_VERSION" != 6.6.*-*-generic ]] && exit 0

update-grub 2>/dev/null

SUBMENU_TITLE=$(grep -m1 "^submenu " "$GRUB_CFG" | sed "s/submenu '\\([^']*\\)'.*/\\1/")
[[ -z "$SUBMENU_TITLE" ]] && exit 1
ENTRY_TITLE="Debian GNU/Linux, with Linux ${KERNEL_VERSION}"
GRUB_DEFAULT_VAL="${SUBMENU_TITLE}>${ENTRY_TITLE}"

sed -i "s|^GRUB_DEFAULT=.*|GRUB_DEFAULT=\"${GRUB_DEFAULT_VAL}\"|" "$GRUB_DEFAULT_FILE"
update-grub 2>/dev/null
HOOK

sudo chmod +x /etc/kernel/postinst.d/zz-prefer-mainline-66-kernel
log_success "已添加 /etc/kernel/postinst.d/zz-prefer-mainline-66-kernel"

log_success "完成，重启后将使用 Linux ${KERNEL_VER}（Ubuntu Mainline）"
