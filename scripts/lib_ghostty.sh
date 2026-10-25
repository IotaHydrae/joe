#!/usr/bin/env bash
# Ghostty 已有安装的兼容修复; 不安装软件包, 不覆盖用户的 Ghostty 配置。

declare -F info >/dev/null 2>&1 || info() { printf '[INFO] %s\n' "$*"; }
declare -F ok >/dev/null 2>&1 || ok() { printf '[SUCCESS] %s\n' "$*"; }
declare -F warn >/dev/null 2>&1 || warn() { printf '[WARNING] %s\n' "$*" >&2; }

ghostty_binary() {
    local candidate
    if command -v ghostty >/dev/null 2>&1; then
        command -v ghostty
        return 0
    fi
    for candidate in "$HOME/.local/bin/ghostty" "$HOME/.local/bin/Ghostty.AppImage" \
                     "$HOME"/Applications/*[Gg]hostty*.AppImage; do
        if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

# 保持 *.bak.<timestamp> 格式, 保留最近 5 份; 同秒内不覆盖备份。
ghostty_backup_file() {
    local source="$1" base="${2:-$1}" backup index=0 old
    backup="$base.bak.$(date +%Y%m%d%H%M%S)"
    while [ -e "$backup" ]; do
        index=$((index + 1))
        backup="$base.bak.$(date +%Y%m%d%H%M%S).$index"
    done
    cp -p -- "$source" "$backup" || return 1
    while IFS= read -r old; do
        rm -f -- "$old" || return 1
    done < <(find "$(dirname "$base")" -maxdepth 1 -type f \
        -name "$(basename "$base").bak.[0-9]*" -print \
        | sort -rV | tail -n +6)
}

# 只在内容变化时备份并原子替换, 保留配置文件的符号链接。
ghostty_write_file() (
    local source="$1" dest="$2" mode="$3" tmp
    if [ -L "$dest" ]; then
        dest="$(readlink -f "$dest")" || return 1
    fi
    [ ! -d "$dest" ] || return 1
    if [ -f "$dest" ] && cmp -s -- "$source" "$dest" \
       && [ "$(stat -c '%a' "$dest")" = "$mode" ]; then
        return 0
    fi
    mkdir -p -- "$(dirname "$dest")" || return 1
    tmp="$(mktemp "$dest.tmp.XXXXXX")" || return 1
    trap 'rm -f -- "$tmp"' EXIT
    install -m "$mode" -- "$source" "$tmp" || return 1
    if [ -f "$dest" ]; then
        ghostty_backup_file "$dest" || return 1
    fi
    mv -f -- "$tmp" "$dest"
)

# 只修复显式 Fixedsys 请求; 不覆盖用户已有的其他 fontconfig 规则。
# 不输出日志, 供中文修复命令与英文 Shell 安装器共用。
ghostty_install_fontconfig() {
    local source dest
    source="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.config/fontconfig/conf.d/99-fixedsys-explicit.conf"
    dest="${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/conf.d/99-fixedsys-explicit.conf"
    [ -s "$source" ] || return 1
    if [ -f "$dest" ] && cmp -s -- "$source" "$dest" \
       && [ "$(stat -c '%a' "$dest")" = 644 ]; then
        return 0
    fi
    ghostty_write_file "$source" "$dest" 644 || return 1
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f || return 1
    fi
}

# 忽略当前用户的 ~/.terminfo 和 TERMINFO 覆盖, 只检查 ncurses 的系统搜索目录。
ghostty_system_terminfo_available() {
    local dir
    command -v infocmp >/dev/null 2>&1 || return 1
    while IFS= read -r dir; do
        [ "$dir" = "$HOME/.terminfo" ] && continue
        if env -u TERMINFO -u TERMINFO_DIRS infocmp -x -A "$dir" xterm-ghostty >/dev/null 2>&1; then
            return 0
        fi
    done < <(env -u TERMINFO -u TERMINFO_DIRS infocmp -D 2>/dev/null)
    return 1
}

ghostty_install_system_terminfo() {
    local work="$1" entry dest install_bin
    if ghostty_system_terminfo_available; then
        info "系统 xterm-ghostty terminfo 已可用 (包括 sudo)"
        return 0
    fi

    # 先用普通用户编译, 只把最终条目以明确的权限写入系统目录。
    tic -x -o "$work/system-terminfo" "$work/ghostty.terminfo" || return 1
    entry="$(find "$work/system-terminfo" -type f -name xterm-ghostty -print -quit)"
    [ -n "$entry" ] || { warn "编译后未找到 xterm-ghostty terminfo"; return 1; }
    dest="/usr/share/terminfo/${entry#"$work/system-terminfo/"}"
    install_bin="$(type -P install)" || return 1
    info "安装系统 terminfo, 让 sudo minicom 等程序也能使用 Ghostty..."
    if [ "$EUID" -eq 0 ]; then
        "$install_bin" -D -m 644 -- "$entry" "$dest" || return 1
    else
        command -v sudo >/dev/null 2>&1 \
            || { warn "系统 terminfo 需要 sudo; 仅修复当前用户可使用 --user-only"; return 1; }
        sudo -- "$install_bin" -D -m 644 -- "$entry" "$dest" \
            || { warn "系统 terminfo 安装失败; 请在自己的终端中运行 ./install.sh repair-ghostty 并完成 sudo 认证"; return 1; }
    fi
    ghostty_system_terminfo_available \
        || { warn "安装后系统仍无法读取 xterm-ghostty terminfo"; return 1; }
    ok "系统 xterm-ghostty terminfo 已安装 (包括 sudo)"
}

ghostty_install_terminfo() {
    local bin="$1" work="$2" user_only="${3:-false}" real prefix entry dir
    command -v infocmp >/dev/null 2>&1 && command -v tic >/dev/null 2>&1 \
        || { warn "需要 ncurses 的 infocmp/tic 来配置 Ghostty terminfo"; return 1; }
    if infocmp -x xterm-ghostty > "$work/ghostty.terminfo" 2>/dev/null; then
        info "当前用户的 xterm-ghostty terminfo 已可用"
    else
        real="$(readlink -f "$bin")" || return 1
        prefix="$(dirname "$(dirname "$real")")"
        dir="$prefix/share/terminfo"
        if ! infocmp -x -A "$dir" xterm-ghostty > "$work/ghostty.terminfo" 2>/dev/null; then
            case "$real" in
                *.[Aa]pp[Ii]mage)
                    info "从 Ghostty AppImage 提取 xterm-ghostty terminfo..."
                    (cd "$work" && "$real" --appimage-extract '**/terminfo/**/xterm-ghostty') \
                        >/dev/null 2>&1 || return 1
                    entry="$(find "$work" -type f -path '*/terminfo/*/xterm-ghostty' -print -quit)"
                    [ -n "$entry" ] || { warn "AppImage 中没有找到 xterm-ghostty terminfo"; return 1; }
                    dir="$(dirname "$(dirname "$entry")")"
                    infocmp -x -A "$dir" xterm-ghostty > "$work/ghostty.terminfo" || return 1
                    ;;
                *)
                    warn "Ghostty 安装缺少 xterm-ghostty terminfo, 请检查软件包是否完整"
                    return 1
                    ;;
            esac
        fi
        tic -x -o "$HOME/.terminfo" "$work/ghostty.terminfo" || return 1
        infocmp -x xterm-ghostty >/dev/null 2>&1 || return 1
        ok "xterm-ghostty terminfo 已安装到 ~/.terminfo"
    fi
    if [ "$user_only" = true ]; then
        if ! ghostty_system_terminfo_available; then
            warn "--user-only 仅修复当前用户; sudo minicom 仍需要系统 terminfo, 运行 ./install.sh repair-ghostty 补齐"
        fi
    else
        ghostty_install_system_terminfo "$work" || return 1
    fi
}

ghostty_install_launcher() {
    local bin="$1" work="$2" source
    source="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/launch_ghostty.sh"
    [ -s "$source" ] || { warn "缺少 Ghostty 启动器: $source"; return 1; }
    {
        printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail'
        printf 'GHOSTTY_BIN=%q\n' "$bin"
        cat -- "$source"
    } > "$work/launcher"
    ghostty_write_file "$work/launcher" "$HOME/.local/bin/joe-ghostty" 755 || return 1
    if [[ ${XDG_SESSION_TYPE:-} == x11 ]] && ! command -v wmctrl >/dev/null 2>&1; then
        warn "X11 新窗口焦点修复需要 wmctrl; 当前保留 Ghostty 原生焦点行为"
    fi
}

# 只迁移直接打开 Ghostty 的现有 Cinnamon 自定义快捷键。
ghostty_refresh_shortcuts() {
    local current updated
    current=$(gsettings get org.cinnamon.desktop.keybindings custom-list) || return 1
    # 与 Cinnamon 设置面板的 ensureCustomListChanges 一致: 切换被忽略的哨兵,
    # 触发 changed::custom-list, 重建内存中的快捷键回调, 保留真实条目及顺序。
    case "$current" in
        *", '__dummy__'"*) updated="${current/, \'__dummy__\'/}" ;;
        *"'__dummy__', "*) updated="${current/\'__dummy__\', /}" ;;
        *"'__dummy__'"*) updated="${current/\'__dummy__\'/}" ;;
        '[]'|'@as []') updated="['__dummy__']" ;;
        *) updated="${current%]}, '__dummy__']" ;;
    esac
    gsettings set org.cinnamon.desktop.keybindings custom-list "$updated"
}

ghostty_configure_shortcuts() {
    local work="$1" config_home launcher command schema id previous
    local refresh=false
    config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    launcher="$HOME/.local/bin/joe-ghostty"
    command -v gsettings >/dev/null 2>&1 || return 0
    gsettings list-schemas | grep -x 'org.cinnamon.desktop.keybindings' >/dev/null || return 0
    while IFS= read -r id; do
        [[ $id =~ ^[a-zA-Z0-9_-]+$ && $id != __dummy__ ]] || continue
        schema="org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/$id/"
        previous=$(gsettings get "$schema" command) || return 1
        case "$previous" in
            "'ghostty'"|"'gtk-launch com.mitchellh.ghostty'"|"'gtk-launch com.mitchellh.ghostty.desktop'") ;;
            *joe-ghostty*) refresh=true; continue ;;
            *) continue ;;
        esac
        printf '%s\n' "$previous" > "$work/shortcut-$id"
        mkdir -p -- "$config_home/ghostty" || return 1
        ghostty_backup_file "$work/shortcut-$id" "$config_home/ghostty/cinnamon-shortcut-$id" || return 1
        printf -v command '%q' "$launcher"
        gsettings set "$schema" command "$command" || return 1
        refresh=true
        ok "Ghostty 快捷键已改用可激活新窗口的启动器 ($id)"
    done < <(gsettings get org.cinnamon.desktop.keybindings custom-list | tr "'" '\n' | awk '/^[a-zA-Z0-9_-]+$/')
    if $refresh; then
        ghostty_refresh_shortcuts || return 1
    fi
}

ghostty_configure_desktop() {
    local bin="$1" work="$2" config_home data_home launcher desktop source dir escaped
    config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    launcher="$HOME/.local/bin/joe-ghostty"
    desktop="$data_home/applications/com.mitchellh.ghostty.desktop"

    ghostty_install_launcher "$bin" "$work" || return 1

    source="$desktop"
    if [ ! -f "$source" ]; then
        local data_dirs
        IFS=: read -ra data_dirs <<< "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
        for dir in "${data_dirs[@]}"; do
            if [ -f "$dir/applications/com.mitchellh.ghostty.desktop" ]; then
                source="$dir/applications/com.mitchellh.ghostty.desktop"
                break
            fi
        done
    fi
    if [ ! -f "$source" ]; then
        source="$work/default.desktop"
        cat > "$source" <<'EOF'
[Desktop Entry]
Type=Application
Name=Ghostty
Exec=ghostty
Icon=com.mitchellh.ghostty
Terminal=false
Categories=System;TerminalEmulator;
Actions=new-window;
X-TerminalArgExec=-e
X-TerminalArgDir=--working-directory=

[Desktop Action new-window]
Name=New Window
Exec=ghostty
EOF
    fi
    # Desktop Exec 有自己的转义规则, 不能复用 shell 的 %q。
    escaped="${launcher//\\/\\\\}"
    escaped="${escaped//\"/\\\"}"
    escaped="${escaped//\$/\\\$}"
    escaped="${escaped//\`/\\\`}"
    escaped="${escaped//%/%%}"
    GHOSTTY_DESKTOP_EXEC="\"$escaped\"" GHOSTTY_LAUNCHER="$launcher" awk '
        function finish() {
            if (section == "[Desktop Entry]") {
                print "TryExec=" ENVIRON["GHOSTTY_LAUNCHER"]
                print "DBusActivatable=false"
            }
        }
        /^\[/ { finish(); section=$0 }
        section == "[Desktop Entry]" && /^(TryExec|DBusActivatable)=/ { next }
        (section == "[Desktop Entry]" || section == "[Desktop Action new-window]") && /^Exec=/ {
            print "Exec=" ENVIRON["GHOSTTY_DESKTOP_EXEC"]; next
        }
        { print }
        END { finish() }
    ' "$source" > "$work/ghostty.desktop"
    ghostty_write_file "$work/ghostty.desktop" "$desktop" 644 || return 1

    # 首选项放最前面, 保留其他终端与注释作为回退。
    local lists=("$config_home/xdg-terminals.list") list
    if [[ "${XDG_CURRENT_DESKTOP:-}" == *[Bb]udgie* ]] || [ -f "$config_home/budgie-xdg-terminals.list" ]; then
        lists+=("$config_home/budgie-xdg-terminals.list")
    fi
    for list in "${lists[@]}"; do
        printf 'com.mitchellh.ghostty.desktop\n' > "$work/terminals.list" || return 1
        if [ -f "$list" ]; then
            awk '$0 != "com.mitchellh.ghostty.desktop"' "$list" >> "$work/terminals.list" || return 1
        fi
        ghostty_write_file "$work/terminals.list" "$list" 644 || return 1
    done

    if command -v gsettings >/dev/null 2>&1 \
       && gsettings list-schemas | grep -x 'org.cinnamon.desktop.default-applications.terminal' >/dev/null; then
        local schema='org.cinnamon.desktop.default-applications.terminal' old_exec old_arg
        old_exec="$(gsettings get "$schema" exec)" || return 1
        old_arg="$(gsettings get "$schema" exec-arg)" || return 1
        if [ "$old_exec" != "'$launcher'" ] || [ "$old_arg" != "'-e'" ]; then
            printf 'exec=%s\nexec-arg=%s\n' "$old_exec" "$old_arg" > "$work/cinnamon-settings"
            mkdir -p "$config_home/ghostty" || return 1
            ghostty_backup_file "$work/cinnamon-settings" "$config_home/ghostty/cinnamon-terminal-settings" || return 1
            gsettings set "$schema" exec "$launcher" || return 1
            gsettings set "$schema" exec-arg '-e' || return 1
        fi
    fi
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$data_home/applications" || return 1
    fi
    ghostty_configure_shortcuts "$work" || return 1
    ok "Ghostty 桌面入口已配置, 打开终端时传入调用目录"
}

# 独立于安装流程, 已安装的软件也会修复; 临时文件在成功/失败时均清理。
repair_ghostty() (
    set -euo pipefail
    local bin work user_only="${1:-false}"
    bin="$(ghostty_binary)" || { warn "未找到 Ghostty, 请先运行 ./install.sh devtools --ghostty"; return 1; }
    work="$(mktemp -d "${TMPDIR:-/tmp}/joe-ghostty.XXXXXX")" || return 1
    trap 'rm -rf -- "$work"' EXIT
    ghostty_install_terminfo "$bin" "$work" "$user_only" || return 1
    ghostty_install_fontconfig || { warn "Fixedsys 字体规则部署失败"; return 1; }
    if ! command -v fc-cache >/dev/null 2>&1; then
        warn "未找到 fc-cache; 安装 fontconfig 后运行 fc-cache -f"
    fi
    ok "Fixedsys 字体优先级规则已配置 (保留中文与表情回退)"
    ghostty_configure_desktop "$bin" "$work" || return 1
)
