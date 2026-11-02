#!/usr/bin/env bash
# =============================================================================
# joe lib/tmp — 临时文件登记与退出清理
# =============================================================================
# 由安装器 source 后使用: 下载 / 解压产生的临时文件登记进 TMP_FILES,
# EXIT 时统一清理, 避免失败中断后残留 /tmp 目录。
#
# 用法:
#   make_tmp <变量名> [后缀]   # 创建临时文件, 路径写入调用方变量并登记
#
# 注意: 不能用 `f=$(make_tmp ...)` 的命令替换形式 —— 那样在子 shell 里登记,
# 父进程的 TMP_FILES 拿不到, EXIT trap 就清不掉了。
# =============================================================================

TMP_FILES=()

cleanup_tmp() {
    if [ ${#TMP_FILES[@]} -gt 0 ]; then
        rm -f -- "${TMP_FILES[@]}"
    fi
}
trap cleanup_tmp EXIT

make_tmp() {
    local __var="$1" __suffix="${2:-}" __f
    if [ -n "$__suffix" ]; then
        __f=$(mktemp --suffix="$__suffix")
    else
        __f=$(mktemp)
    fi
    TMP_FILES+=("$__f")
    printf -v "$__var" '%s' "$__f"
}
