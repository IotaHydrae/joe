#!/usr/bin/env bash
# =============================================================================
# 组件模块: opencode
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 可用安装器的共享助手: info/ok/warn/die, make_tmp, load_nvm, load_pyenv,
# pick_shell_rc, append_shell_cfg, print_ai_followup, 以及 scripts/lib_*.sh。
# =============================================================================

component_opencode_install() {
    info "=== 安装 OpenCode ==="
    export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"
    export XDG_BIN_DIR="${XDG_BIN_DIR:-$HOME/.local/bin}"

    if command -v opencode >/dev/null 2>&1; then
        info "OpenCode 已安装: $(opencode --version 2>/dev/null | head -1)"
    else
        local tpl
        make_tmp tpl .sh
        if download_installer https://opencode.ai/install "$tpl"; then
            info "安装 OpenCode (官方脚本)..."
            if ! bash "$tpl" 2>&1 | tail -3; then
                warn "官方安装脚本执行失败, 尝试 npm"
            fi
            export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"
        else
            warn "官方安装脚本不可用, 尝试 npm"
        fi
        if ! command -v opencode >/dev/null 2>&1; then
            load_node
            command -v node >/dev/null 2>&1 || die "需要 Node (先运行 --node), 官方安装脚本也未装上 OpenCode"
            npm install -g @opencode/cli@latest || die "OpenCode npm 安装失败"
        fi
        command -v opencode >/dev/null 2>&1 || die "OpenCode 安装失败, 请检查网络"
    fi

    ok "OpenCode 就绪: $(opencode --version 2>/dev/null | head -1)"
    print_ai_followup opencode
}
