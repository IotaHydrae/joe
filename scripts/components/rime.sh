#!/usr/bin/env bash
# =============================================================================
# 组件模块: rime (Fcitx 5 + Rime + 雾凇拼音)
# =============================================================================
# 由 install_devtools.sh 在选中时 source, 然后调用 component_<id>_install。
# 包含 Fcitx 5 框架、Rime 引擎、雾凇拼音 (rime-ice) 词库及快捷键配置。
# =============================================================================

rime_present() {
    command -v fcitx5 >/dev/null 2>&1 && [ -f "$HOME/.local/share/fcitx5/rime/default.yaml" ]
}

component_rime_install() {
    info "=== 安装 Rime 雾凇拼音输入法 (Fcitx 5) ==="

    if rime_present; then
        info "Rime 雾凇拼音输入法已安装"
        return 0
    fi

    # 1. 安装系统依赖包
    info "正在安装 Fcitx 5 与 Rime 依赖包..."
    case "$PM" in
        dnf)
            sudo dnf install -y fcitx5 fcitx5-rime fcitx5-chinese-addons fcitx5-configtool \
                fcitx5-gtk fcitx5-qt fcitx5-autostart librime-tools librime-lua
            ;;
        apt)
            sudo apt-get update -qq
            sudo apt-get install -y fcitx5 fcitx5-rime fcitx5-chinese-addons fcitx5-config-qt \
                fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5 fcitx5-frontend-qt6 \
                librime-bin librime-tools 2>/dev/null || \
            sudo apt-get install -y fcitx5 fcitx5-rime fcitx5-chinese-addons fcitx5-config-qt \
                fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5 fcitx5-frontend-qt6 \
                librime-bin
            ;;
        pacman)
            sudo pacman -S --needed --noconfirm fcitx5-im fcitx5-rime fcitx5-chinese-addons librime-tools
            ;;
        zypper)
            sudo zypper install -y fcitx5 fcitx5-rime fcitx5-chinese-addons librime-tools
            ;;
        *)
            die "不支持的包管理器: $PM"
            ;;
    esac

    # 2. 部署雾凇拼音 (rime-ice) 词库
    local rime_dir="$HOME/.local/share/fcitx5/rime"
    mkdir -p "$HOME/.local/share/fcitx5"
    if [ ! -f "$rime_dir/default.yaml" ]; then
        info "正在获取雾凇拼音 (rime-ice) 词库..."
        local -a git_opts=(-c "http.sslVerify=true")
        local proxy="${PROXY_URL:-${https_proxy:-${http_proxy:-}}}"
        if [ -n "$proxy" ]; then
            git_opts+=(-c "http.proxy=$proxy")
        fi
        if [ -d "$rime_dir" ]; then
            rm -rf -- "$rime_dir"
        fi
        if ! git "${git_opts[@]}" clone --depth=1 https://github.com/iDvel/rime-ice.git "$rime_dir"; then
            die "拉取雾凇拼音词库失败。若在内网或遇到网络问题, 可设置 PROXY_URL 后重试"
        fi
    fi
    ln -sfn "$rime_dir" "$HOME/.local/share/rime"

    # 预编译/部署词库
    if command -v rime_deployer >/dev/null 2>&1; then
        info "正在编译 Rime 词库..."
        rime_deployer --build "$rime_dir" >/dev/null 2>&1 || true
    fi

    # 3. 配置输入法列表与默认输入法
    local cfg_dir="$HOME/.config/fcitx5"
    mkdir -p "$cfg_dir"

    # 若 fcitx5 正在运行, 先优雅退出以避免其退出时覆写配置
    if command -v fcitx5-remote >/dev/null 2>&1; then
        fcitx5-remote -e >/dev/null 2>&1 || true
        sleep 1
    fi

    local profile="$cfg_dir/profile"
    if [ ! -f "$profile" ] || ! grep -q "Name=rime" "$profile"; then
        info "配置 Fcitx 5 默认输入法为 Rime..."
        cat > "$profile" <<'EOF'
[Groups/0]
# Group Name
Name=Default
# Layout
Default Layout=us
# Default Input Method
DefaultIM=rime

[Groups/0/Items/0]
# Name
Name=keyboard-us

[Groups/0/Items/1]
# Name
Name=rime

[GroupOrder]
0=Default
EOF
    fi

    # 4. 配置快捷键 (左 Alt + Shift 切换)
    local config="$cfg_dir/config"
    if [ ! -f "$config" ]; then
        cat > "$config" <<'EOF'
[Hotkey/TriggerKeys]
0=Alt+Shift_L
1=Shift+Alt_L
EOF
    elif ! grep -q "0=Alt+Shift_L" "$config"; then
        if grep -q "\[Hotkey/TriggerKeys\]" "$config"; then
            sed -i '/\[Hotkey\/TriggerKeys\]/a 0=Alt+Shift_L\n1=Shift+Alt_L' "$config"
        else
            printf '\n[Hotkey/TriggerKeys]\n0=Alt+Shift_L\n1=Shift+Alt_L\n' >> "$config"
        fi
    fi

    # 5. 配置 Wayland / 桌面会话环境变量
    local env_dir="$HOME/.config/environment.d"
    mkdir -p "$env_dir"
    cat > "$env_dir/im.conf" <<'EOF'
# Input Method Environment Variables for Wayland/Desktop
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF

    # 6. 重新启动 fcitx5 后台服务
    if [ -n "${WAYLAND_DISPLAY:-${DISPLAY:-}}" ]; then
        fcitx5 -d >/dev/null 2>&1 || true
    fi

    ok "Rime 雾凇拼音输入法安装完成 (切换快捷键: 左 Alt + Shift)"
}
