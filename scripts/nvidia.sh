#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

check_sudo

NVIDIA_VERSION="580.126.09"
NVIDIA_RUN="NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run"
NVIDIA_URL="https://download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_VERSION}/${NVIDIA_RUN}"
NVIDIA_CACHE_DIR="$HOME/.cache/nvidia"
NVIDIA_RUN_PATH="${NVIDIA_CACHE_DIR}/${NVIDIA_RUN}"

# ── 检查是否已安装 ──────────────────────────────────────
log_section "NVIDIA 驱动（官方 .run 安装包）"

if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    INSTALLED_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
    if [[ "$INSTALLED_VER" == "$NVIDIA_VERSION" ]]; then
        log_info "NVIDIA 驱动 ${NVIDIA_VERSION} 已安装，跳过"
        exit 0
    else
        log_info "当前版本 ${INSTALLED_VER:-未知}，将升级到 ${NVIDIA_VERSION}"
    fi
fi

# ── 安装编译依赖 ────────────────────────────────────────
log_section "安装编译依赖"
if apt-cache show "linux-headers-$(uname -r)" &>/dev/null; then
    sudo apt install -y gcc make dkms "linux-headers-$(uname -r)"
else
    log_info "linux-headers-$(uname -r) 不在 apt 仓库中，跳过（内核已内置头文件）"
    sudo apt install -y gcc make dkms
fi
log_success "编译依赖就绪"

# ── 下载 ────────────────────────────────────────────────
log_section "下载 NVIDIA 驱动"
mkdir -p "$NVIDIA_CACHE_DIR"
if [[ -f "$NVIDIA_RUN_PATH" ]]; then
    FILE_SIZE=$(stat -c%s "$NVIDIA_RUN_PATH" 2>/dev/null || echo 0)
    if [[ "$FILE_SIZE" -lt 104857600 ]]; then
        log_info "缓存文件不完整（$(( FILE_SIZE / 1024 / 1024 ))MB），重新下载"
        rm -f "$NVIDIA_RUN_PATH"
    else
        log_info "已存在 ${NVIDIA_RUN_PATH}，跳过下载"
    fi
fi
if [[ ! -f "$NVIDIA_RUN_PATH" ]]; then
    gh_wget "$NVIDIA_URL" "$NVIDIA_RUN_PATH"
    log_success "下载完成"
fi
chmod +x "$NVIDIA_RUN_PATH"

# ── 手动安装提示 ──────────────────────────────────────
log_section "手动安装 NVIDIA 驱动"
log_info "请在 tty 终端（Ctrl+Alt+F2）中执行以下命令："
log_info "  sudo systemctl stop display-manager"
log_info "  sudo ${NVIDIA_RUN_PATH} --dkms"
log_info "  sudo systemctl start display-manager"
log_info "  sudo ln -sf /dev/null /etc/udev/rules.d/61-gdm.rules"
log_info "安装完成后重新运行本脚本以配置 Wayland 支持"

# 未安装驱动时跳过后续 Wayland 配置
if ! command -v nvidia-smi &>/dev/null || ! nvidia-smi &>/dev/null; then
    exit 0
fi

# ── 启用 Wayland 支持 ──────────────────────────────────
# 参考：https://us.download.nvidia.com/XFree86/Linux-x86_64/580.126.09/README/kms.html
#       https://us.download.nvidia.com/XFree86/Linux-x86_64/580.126.09/README/gbm.html
log_section "配置 Wayland 支持"

# 1. 开启 DRM KMS（Wayland 必需，NVIDIA 默认关闭）
echo "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia-drm.conf > /dev/null
log_success "已启用 nvidia-drm modeset=1"

# 2. 解除 GDM 对 NVIDIA + Wayland 的封锁（Debian/GNOME 默认禁用）
sudo ln -sf /dev/null /etc/udev/rules.d/61-gdm.rules
log_success "已覆盖 GDM udev 规则，允许 Wayland 登录"

# 3. egl-wayland 已由 .run 安装器内置，无需 apt 安装（apt 版本会覆盖 .run 安装的文件导致 Wayland 黑屏）

# 4. 更新所有内核的 initramfs 使配置生效
sudo update-initramfs -u -k all
log_success "initramfs 已更新"

log_success "完成，请重启系统以加载驱动并启用 Wayland"
