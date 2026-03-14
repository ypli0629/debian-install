#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

check_sudo

NVIDIA_VERSION="580.126.09"
NVIDIA_RUN="NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run"
NVIDIA_URL="https://download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_VERSION}/${NVIDIA_RUN}"

# ── 检查是否已安装 ──────────────────────────────────────
log_section "NVIDIA 驱动（官方 .run 安装包）"

if command -v nvidia-smi &>/dev/null; then
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
sudo apt install -y gcc make linux-headers-"$(uname -r)"
log_success "编译依赖就绪"

# ── 下载 ────────────────────────────────────────────────
log_section "下载 NVIDIA 驱动"
if [[ -f "/tmp/${NVIDIA_RUN}" ]]; then
    log_info "已存在 /tmp/${NVIDIA_RUN}，跳过下载"
else
    gh_wget "$NVIDIA_URL" "/tmp/${NVIDIA_RUN}"
    log_success "下载完成"
fi
chmod +x "/tmp/${NVIDIA_RUN}"

# ── 安装 ────────────────────────────────────────────────
log_section "安装 NVIDIA 驱动"
log_info "将以静默模式运行 .run 安装包..."
sudo "/tmp/${NVIDIA_RUN}" --silent --dkms \
    && log_success "NVIDIA 驱动 ${NVIDIA_VERSION} 安装完成，请重启系统以加载驱动" \
    || log_error "NVIDIA 驱动安装失败，请检查编译日志 /var/log/nvidia-installer.log" fatal
