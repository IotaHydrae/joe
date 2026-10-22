#!/usr/bin/env bash
# =============================================================================
# 组件模块: gemini
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 可用安装器的共享助手: info/ok/warn/die, make_tmp, load_nvm, load_pyenv,
# pick_shell_rc, append_shell_cfg, print_ai_followup, 以及 scripts/lib_*.sh。
# =============================================================================

component_gemini_install() {
    info "=== 安装 Gemini CLI ==="
    export PATH="$HOME/.local/bin:$PATH"

    if command -v gemini >/dev/null 2>&1; then
        info "Gemini CLI 已安装: $(gemini --version 2>/dev/null | head -1)"
    else
        load_node
        command -v node >/dev/null 2>&1 || die "需要 Node (先运行 --node)"
        info "安装 Gemini CLI (@google/gemini-cli)..."
        npm install -g @google/gemini-cli || die "Gemini CLI 安装失败"
        command -v gemini >/dev/null 2>&1 || die "Gemini CLI 安装失败, 请检查网络"
    fi

    ok "Gemini CLI 就绪: $(gemini --version 2>/dev/null | head -1)"
    print_ai_followup gemini
}
