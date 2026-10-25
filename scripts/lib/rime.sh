#!/usr/bin/env bash
# Rime 用户配置修复。可独立 source; 不安装软件包, 不删除用户词库。

declare -F info >/dev/null 2>&1 || info() { printf '[INFO] %s\n' "$*"; }
declare -F warn >/dev/null 2>&1 || warn() { printf '[WARNING] %s\n' "$*" >&2; }

rime_data_dir() {
    printf '%s/fcitx5/rime\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

# 只有没有用户数据时才部署新词库。随机暂存目录由本子 shell 清理。
rime_install_data() (
    local rime_dir stage
    rime_dir="$(rime_data_dir)"
    if [ -f "$rime_dir/default.yaml" ] && [ -f "$rime_dir/rime_ice.schema.yaml" ]; then
        info "保留现有雾凇拼音词库与用户数据: $rime_dir"
        return 0
    fi
    if [ -e "$rime_dir" ] || [ -L "$rime_dir" ]; then
        warn "Rime 数据目录已存在但缺少 default.yaml 或 rime_ice.schema.yaml, 已保留全部内容: $rime_dir"
        warn "请先备份并补齐词库后重试; 安装器不会删除已有输入法数据"
        return 1
    fi
    stage="$(mktemp -d)" || return 1
    trap 'rm -rf -- "$stage"' EXIT
    local -a git_opts=(-c "http.sslVerify=true")
    local proxy="${PROXY_URL:-${https_proxy:-${http_proxy:-}}}"
    [ -z "$proxy" ] || git_opts+=(-c "http.proxy=$proxy")
    info "正在获取雾凇拼音 (rime-ice) 词库..."
    if ! git "${git_opts[@]}" clone --depth=1 https://github.com/iDvel/rime-ice.git "$stage/rime-ice"; then
        warn "拉取雾凇拼音失败; 可设置 PROXY_URL 后重试, 已有输入法数据未改动"
        return 1
    fi
    if [ ! -f "$stage/rime-ice/default.yaml" ] || [ ! -f "$stage/rime-ice/rime_ice.schema.yaml" ]; then
        warn "下载的雾凇拼音词库不完整, 未部署"
        return 1
    fi
    mkdir -p -- "$(dirname "$rime_dir")" || return 1
    # -T 避免在并发出现的目录里再套一层; 非空目标会使 mv 失败。
    mv -T -- "$stage/rime-ice" "$rime_dir" || return 1
)

# 安装状态只表示引擎、已编译词库与用户列表齐备; 会话冲突由 doctor 检查。
rime_installation_ready() {
    local data config
    command -v fcitx5 >/dev/null 2>&1 || return 1
    data="$(rime_data_dir)"
    config="${XDG_CONFIG_HOME:-$HOME/.config}/fcitx5/profile"
    [ -s "$data/build/rime_ice.schema.yaml" ] \
        && [ -s "$data/build/rime_ice.table.bin" ] \
        && [ -s "$data/build/rime_ice.prism.bin" ] \
        && [ -f "$config" ] && grep -q '^Name=rime$' "$config"
}

# 保持 *.bak.<timestamp> 命名, 同秒不覆盖, 仅保留最近五份。
rime_backup_file() {
    local source="$1" backup stamp candidate suffix index=0 old
    if [ -L "$source" ]; then
        source="$(readlink -f "$source")" || return 1
    fi
    [ -f "$source" ] || return 1
    stamp="$(date +%Y%m%d%H%M%S)"
    # 最早的同秒备份可能已被清理, 仍从剩余最大后缀继续编号。
    for candidate in "$source.bak.$stamp" "$source.bak.$stamp".*; do
        [ -e "$candidate" ] || [ -L "$candidate" ] || continue
        if [ "$candidate" = "$source.bak.$stamp" ]; then
            [ "$index" -gt 0 ] || index=1
        else
            suffix="${candidate##*.}"
            if [[ $suffix =~ ^[0-9]+$ ]] && [ "$suffix" -ge "$index" ]; then
                index=$((suffix + 1))
            fi
        fi
    done
    backup="$source.bak.$stamp"
    [ "$index" -eq 0 ] || backup="$backup.$index"
    while [ -e "$backup" ] || [ -L "$backup" ]; do
        index=$((index + 1))
        backup="$source.bak.$stamp.$index"
    done
    cp -p -- "$source" "$backup" || return 1
    while IFS= read -r old; do
        rm -f -- "$old" || return 1
    done < <(find "$(dirname "$source")" -maxdepth 1 -type f \
        -name "$(basename "$source").bak.[0-9]*" -print | sort -rV | tail -n +6)
}

# 原子写入链接的目标; 不替换用户的符号链接, 未变化时不创建备份。
rime_write_file() (
    local source="$1" dest="$2" mode="${3:-600}" tmp
    if [ -L "$dest" ]; then
        dest="$(readlink -f "$dest")" || return 1
    fi
    [ ! -d "$dest" ] || return 1
    if [ -f "$dest" ]; then
        cmp -s -- "$source" "$dest" && return 0
        mode="$(stat -c '%a' "$dest")" || return 1
    fi
    mkdir -p -- "$(dirname "$dest")" || return 1
    tmp="$(mktemp "$dest.tmp.XXXXXX")" || return 1
    trap 'rm -f -- "$tmp"' EXIT
    install -m "$mode" -- "$source" "$tmp" || return 1
    if [ -f "$dest" ]; then
        rime_backup_file "$dest" || return 1
    fi
    mv -f -- "$tmp" "$dest"
)

# 保留组、布局和所有未知字段, 在当前第一组中加入 Rime 并设为默认。
rime_render_profile() {
    awk '
        /^\[/ { section=$0 }
        { lines[NR]=$0; sections[NR]=section }
        /^\[Groups\/[0-9]+\]$/ {
            group=section; sub(/^\[Groups\//, "", group); sub(/\]$/, "", group)
            if (!(group in groups)) { groups[group]=1; group_order[++count]=group }
        }
        section ~ /^\[Groups\/[0-9]+\]$/ && /^Name=/ { names[group]=substr($0, 6) }
        section == "[GroupOrder]" && /^[0-9]+=/ {
            key=$0; sub(/=.*/, "", key)
            if (!have_order || key+0 < order_key) {
                order_key=key+0; preferred=substr($0, index($0, "=")+1); have_order=1
            }
        }
        END {
            if (!count && !NR) {
                print "[Groups/0]\nName=Default\nDefault Layout=us\nDefaultIM=rime"
                print "\n[Groups/0/Items/0]\nName=keyboard-us\n\n[Groups/0/Items/1]\nName=rime"
                print "\n[GroupOrder]\n0=Default"
                exit
            }
            chosen=(count ? group_order[1] : 0)
            for (g in groups) if (names[g] == preferred && have_order) chosen=g
            target="[Groups/" chosen "]"
            for (i=1; i<=NR; i++) {
                if (sections[i] ~ "^\\[Groups/" chosen "/Items/[0-9]+\\]$") {
                    item=sections[i]; sub(/^.*\/Items\//, "", item); sub(/\]$/, "", item)
                    if (item+0 >= next_item) next_item=item+1
                    if (lines[i] == "Name=rime") has_rime=1
                }
                if (sections[i] == target && lines[i] ~ /^DefaultIM=/) has_default=1
            }
            for (i=1; i<=NR; i++) {
                if (i>1 && sections[i-1] == target && sections[i] != target && !has_default) {
                    print "DefaultIM=rime"; has_default=1
                }
                if (sections[i] == target && lines[i] ~ /^DefaultIM=/) print "DefaultIM=rime"
                else print lines[i]
            }
            if (count && NR && sections[NR] == target && !has_default) print "DefaultIM=rime"
            if (!count) print "\n[Groups/0]\nName=Default\nDefault Layout=us\nDefaultIM=rime"
            if (!has_rime) print "\n[Groups/" chosen "/Items/" (next_item+0) "]\nName=rime"
            if (!count && !have_order) print "\n[GroupOrder]\n0=Default"
        }
    ' "$1"
}

# 只追加缺失的切换键, 分配未占用的数字编号。
rime_render_hotkeys() {
    awk '
        /^\[/ { section=$0 }
        { lines[NR]=$0; sections[NR]=section }
        section == "[Hotkey/TriggerKeys]" {
            found=1
            if ($0 ~ /^[0-9]+=/) {
                key=$0; sub(/=.*/, "", key)
                if (key+0 >= next_key) next_key=key+1
                value=substr($0, index($0, "=")+1)
                if (value == "Alt+Shift_L") has_alt=1
                if (value == "Shift+Alt_L") has_shift=1
            }
        }
        function append_keys() {
            if (!has_alt) print next_key++ "=Alt+Shift_L"
            if (!has_shift) print next_key++ "=Shift+Alt_L"
        }
        END {
            for (i=1; i<=NR; i++) {
                if (i>1 && sections[i-1] == "[Hotkey/TriggerKeys]" && sections[i] != sections[i-1] && !added) {
                    append_keys(); added=1
                }
                print lines[i]
            }
            if (!found) print "\n[Hotkey/TriggerKeys]"
            if (!added) append_keys()
        }
    ' "$1"
}

rime_configure_files() {
    local work="$1" config_home profile config environment source
    config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    profile="$config_home/fcitx5/profile"
    config="$config_home/fcitx5/config"
    environment="$config_home/environment.d/im.conf"
    for source in "$profile" "$config" "$environment"; do
        [ ! -e "$source" ] || [ -f "$source" ] \
            || { warn "配置路径不是普通文件, 已保留: $source"; return 1; }
    done
    rime_render_profile "$([ -f "$profile" ] && printf '%s' "$profile" || printf /dev/null)" > "$work/profile" || return 1
    rime_render_hotkeys "$([ -f "$config" ] && printf '%s' "$config" || printf /dev/null)" > "$work/config" || return 1
    awk '
        /^[[:space:]]*(GTK_IM_MODULE|QT_IM_MODULE|XMODIFIERS)[[:space:]]*=/ { next }
        { print }
        END { print "GTK_IM_MODULE=fcitx5\nQT_IM_MODULE=fcitx\nXMODIFIERS=@im=fcitx" }
    ' "$([ -f "$environment" ] && printf '%s' "$environment" || printf /dev/null)" > "$work/im.conf" || return 1
    rime_write_file "$work/profile" "$profile" || return 1
    rime_write_file "$work/config" "$config" || return 1
    rime_write_file "$work/im.conf" "$environment" || return 1
}

rime_deploy_data() {
    local rime_dir="${1:-$(rime_data_dir)}" shared="${2:-/usr/share/rime-data}"
    command -v rime_deployer >/dev/null 2>&1 \
        || { warn "缺少 rime_deployer, 无法编译词库; 请安装 librime 部署工具"; return 1; }
    [ -f "$rime_dir/default.yaml" ] && [ -f "$rime_dir/rime_ice.schema.yaml" ] \
        || { warn "雾凇拼音词库不完整: $rime_dir"; return 1; }
    # 系统共享目录用于解析内置配置; 不存在时仍显式传入用户数据目录。
    [ -d "$shared" ] || shared="$rime_dir"
    info "正在编译 Rime 词库: $rime_dir"
    if ! rime_deployer --build "$rime_dir" "$shared" "$rime_dir/build"; then
        warn "Rime 词库编译失败; 请检查上面的输出与 rime.tools 日志"
        return 1
    fi
    if [ ! -s "$rime_dir/build/rime_ice.schema.yaml" ] || [ ! -s "$rime_dir/build/rime_ice.table.bin" ] \
       || [ ! -s "$rime_dir/build/rime_ice.prism.bin" ]; then
        warn "编译结束但未生成雾凇拼音的方案/词典, 请检查 rime.tools 日志"
        return 1
    fi
}

rime_live_session() {
    [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]
}

rime_wait_stopped() {
    local name="$1" uid="$2" attempt
    for ((attempt=0; attempt<30; attempt++)); do
        pgrep -u "$uid" -x "$name" >/dev/null 2>&1 || return 0
        sleep 0.1
    done
    return 1
}

rime_stop_session() {
    rime_live_session || return 0
    local uid
    uid="$(id -u)" || return 1
    if pgrep -u "$uid" -x fcitx5 >/dev/null 2>&1; then
        fcitx5-remote -e || { warn "无法退出当前 Fcitx 5, 未继续修改运行中的配置"; return 1; }
        rime_wait_stopped fcitx5 "$uid" || { warn "Fcitx 5 未能退出"; return 1; }
    fi
    if pgrep -u "$uid" -x fcitx >/dev/null 2>&1; then
        info "退出当前用户的旧 Fcitx 后台, 避免与 Fcitx 5 争用输入法"
        if command -v fcitx-remote >/dev/null 2>&1; then
            fcitx-remote -e || return 1
        elif command -v gdbus >/dev/null 2>&1; then
            gdbus call --session --dest org.fcitx.Fcitx --object-path /inputmethod \
                --method org.fcitx.Fcitx.InputMethod.Exit || return 1
        else
            warn "旧 Fcitx 正在运行但缺少退出工具; 请先退出旧输入法后台或注销后重试"
            return 1
        fi
        rime_wait_stopped fcitx "$uid" \
            || { warn "旧 Fcitx 未能退出; 已保留其配置, 请退出旧后台后重试"; return 1; }
    fi
}

rime_configure_session() (
    local xinputrc="$HOME/.xinputrc" work autostart
    if command -v im-config >/dev/null 2>&1; then
        [ "$(id -u)" != 0 ] \
            || { warn "请以桌面用户运行 Rime 配置; root 的 im-config 会修改系统配置"; return 1; }
        if [ -f "$xinputrc" ] && grep -Eq '^run_im[[:space:]]+fcitx5[[:space:]]*$' "$xinputrc"; then
            return 0
        fi
        if [ -e "$xinputrc" ] || [ -L "$xinputrc" ]; then
            rime_backup_file "$xinputrc" || return 1
        fi
        if ! im-config -n fcitx5; then
            warn "im-config 未能选择 Fcitx 5; 自定义 .xinputrc 已保留, 请调整其中的输入法选择后重试"
            return 1
        fi
        return 0
    fi
    work="$(mktemp -d)" || return 1
    trap 'rm -rf -- "$work"' EXIT
    autostart="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/org.fcitx.Fcitx5.desktop"
    awk '
        function add_missing() {
            if (!type) print "Type=Application"
            if (!name) print "Name=Fcitx 5"
            if (!exec) print "Exec=fcitx5 -d"
            if (!hidden) print "Hidden=false"
            if (!enabled) print "X-GNOME-Autostart-enabled=true"
        }
        /^\[/ {
            if (section == "[Desktop Entry]") { add_missing(); added=1 }
            section=$0
            if (section == "[Desktop Entry]") found=1
        }
        section == "[Desktop Entry]" && /^Type=/ { type=1 }
        section == "[Desktop Entry]" && /^Name=/ { name=1 }
        section == "[Desktop Entry]" && /^Exec=/ { print "Exec=fcitx5 -d"; exec=1; next }
        section == "[Desktop Entry]" && /^Hidden=/ { print "Hidden=false"; hidden=1; next }
        section == "[Desktop Entry]" && /^X-GNOME-Autostart-enabled=/ { print "X-GNOME-Autostart-enabled=true"; enabled=1; next }
        { print }
        END {
            if (!found) print "[Desktop Entry]"
            if (!added) add_missing()
        }
    ' "$([ -f "$autostart" ] && printf '%s' "$autostart" || printf /dev/null)" > "$work/autostart" || return 1
    rime_write_file "$work/autostart" "$autostart" 644
)

rime_start_session() {
    rime_live_session || return 0
    local uid attempt state
    uid="$(id -u)" || return 1
    export GTK_IM_MODULE=fcitx5 QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx
    fcitx5 -rd || { warn "Fcitx 5 启动失败"; return 1; }
    for ((attempt=0; attempt<30; attempt++)); do
        if pgrep -u "$uid" -x fcitx5 >/dev/null 2>&1; then
            state="$(fcitx5-remote)" || state=""
            [[ $state =~ ^[012]$ ]] && return 0
        fi
        sleep 0.1
    done
    warn "Fcitx 5 启动后未能响应; 请检查会话 D-Bus 与输入法日志"
    return 1
}

rime_repair_user_config() (
    local work restart=false
    work="$(mktemp -d)" || return 1
    trap 'rm -rf -- "$work"; if $restart; then rime_start_session || warn "修复失败后重新启动输入法也失败, 请注销后重试"; fi' EXIT
    command -v fcitx5 >/dev/null 2>&1 || { warn "缺少 fcitx5"; return 1; }
    # im-config 拒绝自定义文件时不打断当前输入法。
    rime_configure_session || return 1
    restart=true
    rime_stop_session || return 1
    rime_deploy_data || return 1
    rime_configure_files "$work" || return 1
    rime_start_session || return 1
    restart=false
)
