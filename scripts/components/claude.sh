#!/usr/bin/env bash
# =============================================================================
# 组件模块: claude
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 可用安装器的共享助手: info/ok/warn/die, make_tmp, load_nvm, load_pyenv,
# pick_shell_rc, append_shell_cfg, print_ai_followup, 以及 scripts/lib_*.sh。
# =============================================================================

component_claude_install() {
    info "=== 安装 Claude Code ==="
    export PATH="$HOME/.local/bin:$PATH"

    if command -v claude >/dev/null 2>&1; then
        info "Claude Code 已安装: $(claude --version 2>/dev/null | head -1)"
    else
        # 优先官方安装脚本 (npm 方式已被官方标记 deprecated)
        local tpl
        make_tmp tpl .sh
        if download_installer https://claude.ai/install.sh "$tpl"; then
            info "安装 Claude Code (官方脚本)..."
            if ! bash "$tpl" 2>&1 | tail -3; then
                warn "官方安装脚本执行失败, 尝试 npm"
            fi
            export PATH="$HOME/.local/bin:$PATH"
        else
            warn "官方安装脚本不可用 (网络/区域限制), 尝试 npm"
        fi
        if ! command -v claude >/dev/null 2>&1; then
            load_node
            command -v node >/dev/null 2>&1 || die "需要 Node (先运行 --node), 官方安装脚本也未装上 Claude Code"
            npm install -g --allow-scripts=@anthropic-ai/claude-code @anthropic-ai/claude-code \
                || die "Claude Code npm 安装失败"
        fi
        command -v claude >/dev/null 2>&1 || die "Claude Code 安装失败, 请检查网络"
    fi

    ok "Claude Code 就绪: $(claude --version 2>/dev/null | head -1)"
    print_ai_followup claude
}
