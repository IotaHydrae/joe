#!/usr/bin/env bash
# =============================================================================
# 组件模块: node
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 可用安装器的共享助手: info/ok/warn/die, make_tmp, load_nvm, load_pyenv,
# pick_shell_rc, append_shell_cfg, print_ai_followup, 以及 scripts/lib_*.sh。
# =============================================================================

component_node_install() {
    info "=== 安装 nvm (Node Version Manager) ==="
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    if [ -d "$NVM_DIR" ]; then
        info "nvm 已存在, 跳过安装"
        load_nvm
    else
        curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | PROFILE=/dev/null bash
        load_nvm
    fi

    # 非交互调用也先使用固定运行路径, 确保迁移的是当前版本的全局包。
    load_node
    local target previous
    if [ -n "$NODE_LTS" ]; then
        target="$(nvm version-remote "$NODE_LTS")" || die "无法解析 Node 版本, 请检查网络"
    else
        target="$(nvm version-remote --lts)" || die "无法解析 Node LTS 版本, 请检查网络"
    fi
    [[ "$target" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "无法解析 Node LTS 版本, 请检查网络"
    if [ -e "$NVM_DIR/current" ] && [ ! -L "$NVM_DIR/current" ]; then
        die "$NVM_DIR/current 不是符号链接, 请检查后再安装"
    fi
    previous="$(nvm current)" || previous=none
    case "$previous" in
        N/A|none|'') previous="$(nvm version default)" || previous=none ;;
    esac
    local args=("$target")
    case "$previous" in
        "$target"|N/A|none|'') ;;
        *) args+=("--reinstall-packages-from=$previous") ;;
    esac
    info "安装/切换 Node: $target"
    NVM_SYMLINK_CURRENT=true nvm install "${args[@]}"
    nvm alias default "$target"
    [ -x "$NVM_DIR/current/bin/node" ] || die "Node current 链接未创建"
    configure_node_shell "$(pick_shell_rc)" "$NVM_DIR"
    load_node
    ok "Node 已就绪: $(node --version) (shell 只设置 PATH, 不初始化 nvm)"
}
