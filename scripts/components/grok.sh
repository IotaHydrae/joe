#!/usr/bin/env bash
# =============================================================================
# 组件模块: grok
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 可用安装器的共享助手: info/ok/warn/die, make_tmp, load_nvm, load_pyenv,
# pick_shell_rc, append_shell_cfg, print_ai_followup, 以及 scripts/lib_*.sh。
# =============================================================================

component_grok_install() {
    info "=== 安装 Grok Build ==="
    export PATH="$HOME/.grok/bin:$HOME/.local/bin:$PATH"

    if { command -v grok >/dev/null 2>&1 || [ -x "$HOME/.grok/bin/grok" ]; } \
        && [ "${GROK_FORCE:-}" != 1 ]; then
        info "Grok Build 已安装: $(grok --version 2>/dev/null | head -1)"
    else
        local tpl
        make_tmp tpl .sh
        if ! download_installer https://x.ai/cli/install.sh "$tpl"; then
            die "无法下载 Grok Build 安装脚本: https://x.ai/cli/install.sh"
        fi
        info "安装 Grok Build (官方脚本)..."
        if ! bash "$tpl" 2>&1 | tail -5; then
            die "Grok Build 官方安装脚本失败"
        fi
        export PATH="$HOME/.grok/bin:$HOME/.local/bin:$PATH"
        if ! command -v grok >/dev/null 2>&1 && [ ! -x "$HOME/.grok/bin/grok" ]; then
            die "Grok Build 安装失败, 请检查网络"
        fi
    fi

    ok "Grok Build 就绪: $(grok --version 2>/dev/null | head -1)"
    print_ai_followup grok
}
