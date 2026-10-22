#!/usr/bin/env bash
# =============================================================================
# 组件模块: zed
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 可用安装器的共享助手: info/ok/warn/die, make_tmp, load_nvm, load_pyenv,
# pick_shell_rc, append_shell_cfg, print_ai_followup, 以及 scripts/lib_*.sh。
# =============================================================================

component_zed_install() {
    info "=== 安装 Zed 编辑器 ==="

    # Vulkan (Zed 依赖 GPU 渲染) - 按发行版自动映射包名
    if ! command -v vulkaninfo >/dev/null 2>&1; then
        install_sys_pkg vulkan-loader vulkan-tools mesa-vulkan-drivers
    fi

    # JetBrains Mono 字体
    if ! fc-list 2>/dev/null | grep -qi "jetbrains mono"; then
        install_sys_pkg jetbrains-mono
    fi

    # Zed 本体 (官方安装脚本)
    if [ ! -x "$HOME/.local/bin/zed" ]; then
        curl -f https://zed.dev/install.sh | sh
    else
        info "Zed 已安装: $($HOME/.local/bin/zed --version | head -1)"
    fi

    # PATH 配置
    local rc_file
    rc_file=$(pick_shell_rc)
    if ! grep -q '\.local/bin' "$rc_file" 2>/dev/null; then
        printf '%s\n' 'export PATH=$HOME/.local/bin:$PATH' >> "$rc_file"
        info "$rc_file 已追加 ~/.local/bin 到 PATH"
    fi

    # Zed 默认字体配置; 已有配置时保留, 不覆盖用户设置
    if [ -f "$HOME/.config/zed/settings.json" ]; then
        info "Zed settings.json 已存在, 保留用户配置不覆盖"
    else
        mkdir -p "$HOME/.config/zed"
        cat > "$HOME/.config/zed/settings.json" << 'EOF'
{
  "ui_font_family": "JetBrains Mono",
  "ui_font_size": 14,
  "buffer_font_family": "JetBrains Mono",
  "buffer_font_size": 14,
  "terminal": {
    "font_family": "JetBrains Mono",
    "font_size": 14
  }
}
EOF
        info "已写入 Zed 默认字体配置 (JetBrains Mono)"
    fi
    ok "Zed 配置完成"
}
