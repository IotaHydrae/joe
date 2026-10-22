#!/usr/bin/env bash
# =============================================================================
# 组件模块: codex
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 可用安装器的共享助手: info/ok/warn/die, make_tmp, load_nvm, load_pyenv,
# pick_shell_rc, append_shell_cfg, print_ai_followup, 以及 scripts/lib_*.sh。
# =============================================================================

component_codex_install() {
    info "=== 安装 Codex CLI ==="
    export PATH="$HOME/.local/bin:$PATH"

    if command -v codex >/dev/null 2>&1; then
        info "Codex CLI 已安装: $(codex --version 2>/dev/null | head -1)"
    else
        load_node
        command -v node >/dev/null 2>&1 || die "需要 Node (先运行 --node)"
        info "安装 Codex CLI (@openai/codex)..."
        npm install -g @openai/codex || die "Codex CLI 安装失败"
        command -v codex >/dev/null 2>&1 || die "Codex CLI 安装失败, 请检查网络"
    fi

    ok "Codex CLI 就绪: $(codex --version 2>/dev/null | head -1)"
    print_ai_followup codex
}
