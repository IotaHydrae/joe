#!/usr/bin/env bash
# Fcitx 5 + Rime + 雾凇拼音; 重复安装也会检查并修复用户配置。

# shellcheck source=../lib/rime.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/rime.sh"

rime_present() {
    command -v fcitx5 >/dev/null 2>&1 && [ -f "$(rime_data_dir)/default.yaml" ]
}

component_rime_install() {
    info "=== 安装/修复 Rime 雾凇拼音输入法 (Fcitx 5) ==="
    info "正在检查 Fcitx 5、GTK/Qt 前端与 Rime Lua 依赖..."
    case "$PM" in
        dnf)
            sudo dnf install -y fcitx5 fcitx5-rime fcitx5-chinese-addons fcitx5-configtool \
                fcitx5-gtk fcitx5-qt fcitx5-autostart librime-tools librime-lua \
                || die "Fcitx 5 / Rime 依赖安装失败"
            ;;
        apt)
            sudo apt-get update -qq || die "更新软件包索引失败"
            sudo apt-get install -y fcitx5 fcitx5-rime fcitx5-chinese-addons fcitx5-config-qt \
                fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5 fcitx5-frontend-qt6 \
                librime-bin librime-plugin-lua im-config || die "Fcitx 5 / Rime 依赖安装失败"
            ;;
        pacman)
            # Arch 的 librime 同时提供 rime_deployer 与 librime-lua 插件。
            sudo pacman -S --needed --noconfirm fcitx5-im fcitx5-rime fcitx5-chinese-addons librime \
                || die "Fcitx 5 / Rime 依赖安装失败"
            ;;
        zypper)
            sudo zypper install -y fcitx5 fcitx5-rime fcitx5-chinese-addons \
                fcitx5-gtk3 fcitx5-gtk4 fcitx5-qt5 fcitx5-qt6 rime librime-lua \
                || die "Fcitx 5 / Rime 依赖安装失败"
            ;;
        *) die "不支持的包管理器: $PM" ;;
    esac
    rime_install_data || die "雾凇拼音词库未能安全部署"
    rime_repair_user_config || die "Rime 配置/部署失败, 请查看上面的错误"
    ok "Rime 雾凇拼音输入法配置完成 (新增切换键: 左 Alt + Shift; 已保留原快捷键)"
}
