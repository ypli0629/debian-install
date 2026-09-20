#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/utils.sh"

check_sudo

log_section "oh-my-zsh"

# 就绪标志：oh-my-zsh.sh 存在才算安装成功
OMZ_READY=0
if [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
    log_info "oh-my-zsh 已安装，跳过"
    OMZ_READY=1
else
    # 先下载到临时文件，校验非空与语法后再执行，避免下载失败时执行空/损坏脚本
    OMZ_INSTALLER=""
    if ! OMZ_INSTALLER="$(mktemp)"; then
        record_failure "oh-my-zsh" "创建临时文件失败"
    else
        if gh_wget "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" "$OMZ_INSTALLER" \
            && [[ -s "$OMZ_INSTALLER" ]]; then
            if ! sh -n "$OMZ_INSTALLER" 2>/dev/null; then
                record_failure "oh-my-zsh" "下载脚本语法校验失败"
            elif sh "$OMZ_INSTALLER" "" --unattended </dev/null; then
                if [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
                    OMZ_READY=1
                    log_success "oh-my-zsh 安装完成"
                else
                    record_failure "oh-my-zsh" "执行安装脚本后未找到 oh-my-zsh.sh"
                fi
            else
                record_failure "oh-my-zsh" "安装脚本执行失败"
            fi
        else
            record_failure "oh-my-zsh" "下载安装脚本失败或文件为空"
        fi
        rm -f "$OMZ_INSTALLER"
    fi
fi

# --unattended 不会自动 chsh，仅当 oh-my-zsh 就绪时才切换默认 shell
if [[ $OMZ_READY -eq 1 ]]; then
    ZSH_BIN="$(command -v zsh 2>/dev/null || echo "")"
    if [[ -n "$ZSH_BIN" && "$SHELL" != "$ZSH_BIN" ]]; then
        # 确保 zsh 在 /etc/shells 中
        grep -qF "$ZSH_BIN" /etc/shells || echo "$ZSH_BIN" | sudo tee -a /etc/shells > /dev/null
        sudo chsh -s "$ZSH_BIN" "$USER"
        log_success "默认 Shell 已切换为 $ZSH_BIN"
    else
        log_info "默认 Shell 已是 zsh，跳过"
    fi
else
    log_info "oh-my-zsh 未就绪，跳过默认 Shell 切换"
fi

log_section "zsh 插件"
PLUGINS_OK=()
git_clone_or_skip https://github.com/zsh-users/zsh-autosuggestions \
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" \
    && PLUGINS_OK+=(zsh-autosuggestions) \
    || record_failure "zsh-autosuggestions" "克隆失败或目标目录非 git 仓库"
git_clone_or_skip https://github.com/zsh-users/zsh-syntax-highlighting \
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" \
    && PLUGINS_OK+=(zsh-syntax-highlighting) \
    || record_failure "zsh-syntax-highlighting" "克隆失败或目标目录非 git 仓库"

# 仅对克隆成功的插件写入 plugins=()，避免启用不存在的插件导致 zsh 启动报错
for plugin in "${PLUGINS_OK[@]}"; do
    # 用 grep -F 匹配完整插件名，避免子字符串误判
    if grep -qF "$plugin" ~/.zshrc 2>/dev/null; then
        log_info "插件已启用：$plugin，跳过"
    else
        # 仅替换单行 plugins=(...)；若 .zshrc 是多行格式，提示用户手动处理
        if grep -qE "^plugins=\(.*\)[[:space:]]*$" ~/.zshrc 2>/dev/null; then
            sed -i "s/^plugins=(\(.*\))/plugins=(\1 ${plugin})/" ~/.zshrc
            log_success "已启用插件：$plugin"
        else
            log_info "plugins=() 可能是多行格式，请手动将 ${plugin} 加入 ~/.zshrc 的 plugins 列表"
        fi
    fi
done

log_section "zshrc 配置"
append_zshrc_once "# >>> debian13-install >>>" "$(cat <<'EOF'
# >>> debian13-install >>>
alias szsh="source ~/.zshrc"
alias nzsh="nvim ~/.zshrc"
alias pon="export http_proxy=http://127.0.0.1:7890; export https_proxy=http://127.0.0.1:7890; export all_proxy=socks5://127.0.0.1:7890"
alias poff="unset http_proxy; unset https_proxy; unset all_proxy"

export PATH=~/.local/bin:~/go/bin:/usr/local/sbin:/usr/sbin:$PATH
___MY_VMOPTIONS_SHELL_FILE="${HOME}/.jetbrains.vmoptions.sh"; if [ -f "${___MY_VMOPTIONS_SHELL_FILE}" ]; then . "${___MY_VMOPTIONS_SHELL_FILE}"; fi

# fzf shell 集成：Ctrl+R 历史搜索 / Ctrl+T 文件搜索 / Alt+C 目录跳转
command -v fzf &>/dev/null && eval "$(fzf --zsh)"
# <<< debian13-install <<<
EOF
)"

log_success "zsh 完成"
finish || exit 1
