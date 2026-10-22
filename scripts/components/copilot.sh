#!/usr/bin/env bash
# =============================================================================
# 组件模块: copilot
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 可用安装器的共享助手: info/ok/warn/die, make_tmp, load_nvm, load_pyenv,
# pick_shell_rc, append_shell_cfg, print_ai_followup, 以及 scripts/lib_*.sh。
# =============================================================================

component_copilot_install() {
    info "=== 安装 GitHub Copilot CLI ==="
    export PATH="$HOME/.local/bin:$PATH"

    if command -v copilot >/dev/null 2>&1 && [ "${COPILOT_FORCE:-}" != 1 ]; then
        info "Copilot CLI 已安装: $(copilot --version 2>/dev/null | head -1)"
    else
        local tpl
        make_tmp tpl .sh
        # 非 root 默认装到 ~/.local/bin, 显式 PREFIX 避免写到 /usr/local。
        if download_installer https://gh.io/copilot-install "$tpl"; then
            info "安装 Copilot CLI (官方脚本)..."
            if ! env PREFIX="$HOME/.local" bash "$tpl" 2>&1 | tail -3; then
                warn "官方安装脚本执行失败, 尝试 npm"
            fi
            export PATH="$HOME/.local/bin:$PATH"
        else
            warn "官方安装脚本不可用, 尝试 npm"
        fi
        if ! command -v copilot >/dev/null 2>&1; then
            if [ "${COPILOT_FORCE:-}" = 1 ]; then
                die "Copilot CLI 升级失败"
            fi
            load_node
            command -v node >/dev/null 2>&1 || die "需要 Node (先运行 --node), 官方安装脚本也未装上 Copilot CLI"
            npm install -g @github/copilot || die "Copilot CLI npm 安装失败"
        fi
        command -v copilot >/dev/null 2>&1 || die "Copilot CLI 安装失败, 请检查网络"
    fi

    ok "Copilot CLI 就绪: $(copilot --version 2>/dev/null | head -1)"
    printf '下一步: 运行 copilot 完成 GitHub 登录。MCP 用 copilot mcp add 配置。\n'
}
