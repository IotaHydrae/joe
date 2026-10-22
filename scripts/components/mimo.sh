#!/usr/bin/env bash
# =============================================================================
# 组件模块: mimo
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 可用安装器的共享助手: info/ok/warn/die, make_tmp, load_nvm, load_pyenv,
# pick_shell_rc, append_shell_cfg, print_ai_followup, 以及 scripts/lib_*.sh。
# =============================================================================

component_mimo_install() {
    info "=== 安装 MiMo Code (小米 AI 编程助手) ==="

    load_node
    # 官方安装路径 (~/.mimocode/bin) 与用户级 bin
    export PATH="$HOME/.mimocode/bin:$HOME/.local/bin:$PATH"

    if command -v mimo >/dev/null 2>&1; then
        info "MiMo Code 已安装: $(mimo --version 2>/dev/null | head -1)"
    else
        # 官方脚本 (macOS/Linux 推荐; Windows 官方为 npm)
        local tpl
        make_tmp tpl .sh
        if download_installer https://mimo.xiaomi.com/install "$tpl"; then
            info "安装 MiMo Code (官方脚本)..."
            if ! bash "$tpl" 2>&1 | tail -3; then
                warn "官方安装脚本执行失败, 尝试 npm"
            fi
            export PATH="$HOME/.mimocode/bin:$HOME/.local/bin:$PATH"
        else
            warn "官方安装脚本不可用, 回退 npm"
        fi
        if ! command -v mimo >/dev/null 2>&1; then
            command -v node >/dev/null 2>&1 || die "需要 Node (先运行 --node) 或手动安装 MiMo Code"
            npm install -g --allow-scripts=@mimo-ai/cli @mimo-ai/cli || die "MiMo Code npm 安装失败"
        fi
    fi

    if ! command -v mimo >/dev/null 2>&1; then
        die "MiMo Code 安装失败, 请检查网络"
    fi

    ok "MiMo Code 配置完成: $(mimo --version 2>/dev/null | head -1)"
}
