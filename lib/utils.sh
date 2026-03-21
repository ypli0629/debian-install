#!/bin/bash

# ── 颜色 ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# ── 日志 ──────────────────────────────────────────────────
log_section() { echo -e "\n${BOLD}${BLUE}══ $1 ══${NC}"; }
log_info()    { echo -e "${YELLOW}  → $1${NC}"; }
log_success() { echo -e "${GREEN}  ✓ $1${NC}"; }
log_error()   { echo -e "${RED}  ✗ $1${NC}" >&2; [[ "${2:-}" == "fatal" ]] && exit 1; }

# ── sudo 预热 ─────────────────────────────────────────────
check_sudo() {
    if ! sudo -v 2>/dev/null; then
        log_error "需要 sudo 权限" fatal
    fi
    # 确保 curl/wget 可用（Debian 最小安装不自带）
    local _missing=()
    command -v curl &>/dev/null || _missing+=(curl)
    command -v wget &>/dev/null || _missing+=(wget)
    if [[ ${#_missing[@]} -gt 0 ]]; then
        log_info "安装基础工具：${_missing[*]}"
        sudo apt-get install -y "${_missing[@]}" -qq
    fi
    # 保持 sudo 会话不过期
    ( while true; do sudo -v; sleep 50; done ) &
    SUDO_KEEP_ALIVE_PID=$!
    trap 'kill "$SUDO_KEEP_ALIVE_PID" 2>/dev/null' EXIT INT TERM
}

# ── curl / wget 封装 ──────────────────────────────────────
gh_curl() {
    local url="$1"; shift
    curl -fsSL --connect-timeout 30 "$@" "$url"
}

gh_wget() {
    local url="$1"
    local output="$2"
    if [[ -z "$url" ]]; then
        echo -e "${RED}  ✗ 下载 URL 为空${NC}" >&2
        return 1
    fi
    wget --timeout=60 --show-progress -O "$output" "$url"
}

# ── Git clone（已存在则跳过）──────────────────────────────
git_clone_or_skip() {
    local repo="$1"
    local dest="$2"
    if [[ -d "$dest/.git" ]]; then
        log_info "已存在，跳过：$dest"
        return 0
    fi
    git clone "$repo" "$dest"
}

# ── 进度条 ────────────────────────────────────────────────
PROGRESS_TOTAL=0
PROGRESS_CURRENT=0

progress_init() {
    PROGRESS_TOTAL="${1:-0}"
    PROGRESS_CURRENT=0
    [[ -t 1 ]] && printf '\n'   # 为底部进度条预留一行
}

_progress_draw() {
    [[ ! -t 1 ]] && return
    [[ "$PROGRESS_TOTAL" -eq 0 ]] && return
    command -v tput &>/dev/null || return
    local cols lines width filled empty bar pct i
    cols=$(tput cols 2>/dev/null || echo 80)
    lines=$(tput lines 2>/dev/null || echo 24)
    width=$(( cols - 24 ))
    [[ $width -lt 10 ]] && width=10
    filled=$(( PROGRESS_CURRENT * width / PROGRESS_TOTAL ))
    empty=$(( width - filled ))
    bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    pct=$(( PROGRESS_CURRENT * 100 / PROGRESS_TOTAL ))
    tput sc 2>/dev/null || return
    tput cup $(( lines - 1 )) 0 2>/dev/null || { tput rc 2>/dev/null; return; }
    printf "\033[K${BOLD}${BLUE} 进度 [${GREEN}%s${BLUE}] %d/%d (${GREEN}%3d%%${BLUE})${NC}" \
        "$bar" "$PROGRESS_CURRENT" "$PROGRESS_TOTAL" "$pct"
    tput rc 2>/dev/null || true
}

progress_tick() {
    PROGRESS_CURRENT=$(( PROGRESS_CURRENT + 1 ))
    _progress_draw
}

# ── 安全追加 ~/.zshrc（避免重复写入）─────────────────────
append_zshrc_once() {
    local marker="$1"   # 用于判断是否已写入的标识字符串
    local content="$2"
    if ! grep -qF "$marker" ~/.zshrc 2>/dev/null; then
        printf '\n%s\n' "$content" >> ~/.zshrc
    else
        log_info "zshrc 中已存在：$marker，跳过"
    fi
}

# ── 安装报告 ────────────────────────────────────────────────
FAILED_STEPS=()

record_failure() {
    local step="$1"
    local reason="${2:-}"
    FAILED_STEPS+=("${step}${reason:+（${reason}）}")
    log_error "跳过：${step}${reason:+（${reason}）}"
}

print_report() {
    echo ""
    if [[ ${#FAILED_STEPS[@]} -eq 0 ]]; then
        log_success "全部步骤执行完成！"
    else
        echo -e "${RED}${BOLD}══ 安装报告：以下步骤失败，请手动处理 ══${NC}"
        for step in "${FAILED_STEPS[@]}"; do
            echo -e "${RED}  ✗ ${step}${NC}"
        done
        echo ""
    fi
}
