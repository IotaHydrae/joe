#!/bin/bash
# We assume you're using bash

set -euo pipefail

# Assets remain at the repository root; resolve it independently of cwd.
SCRIPT_DIR="$(pwd)"
if [ -f "${BASH_SOURCE[0]:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
    cd "$SCRIPT_DIR"
fi

# When the script is piped through `curl ... | bash`, there is no script
# file: clone this repository and re-execute from the clone so that
# repo-local assets (.config, fonts, .p10k.zsh) are included as well.
if [ ! -f "${BASH_SOURCE[0]:-}" ]; then
    JOE_INSTALL_DIR="${JOE_INSTALL_DIR:-$HOME/.joe}"
    if [ ! -d "$JOE_INSTALL_DIR/.git" ]; then
        if [ -e "$JOE_INSTALL_DIR" ]; then
            echo "ERROR: $JOE_INSTALL_DIR exists but is not a joe git repository; remove it or set JOE_INSTALL_DIR to another location" >&2
            exit 1
        fi
        if ! command -v git >/dev/null 2>&1; then
            echo "ERROR: git is required for one-line installation" >&2
            exit 1
        fi
        echo "Cloning joe repository to $JOE_INSTALL_DIR..."
        git clone --depth=1 https://github.com/IotaHydrae/joe.git "$JOE_INSTALL_DIR"
    fi
    exec bash "$JOE_INSTALL_DIR/install.sh" shell "$@"
fi

# Configuration and constants
OMZ_INSTALL_DIR=~/.oh-my-zsh
PL10K_INSTALL_DIR=~/.powerlevel10k
ZSH_AUTOSUGGESTIONS_DIR=~/.zsh-autosuggestions
ZSH_SYNTAX_HIGHLIGHTING_DIR=~/.zsh-syntax-highlighting
GHOSTTY_IMMODULE_DIR=~/.local/share/ghostty-appimage/gtk-immodules
LOG_FILE="$SCRIPT_DIR/install.log"
BACKUP_RETENTION=5

# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/lib/zsh.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/lib_ghostty.sh"

# Use sudo for privileged commands unless we are already root
if [ "$EUID" -eq 0 ]; then
    SUDO_CMD=""
else
    SUDO_CMD="sudo"
fi

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Command line flags
DRY_RUN=false
NO_FONTS=false
NO_CONFIG=false
NO_P10K=false
NO_FASTFETCH=false
NO_DEFAULT_PLUGINS=false
NO_GHOSTTY_IME=false
CLEAN_BACKUPS=false
UPDATE_MODE=false
SHOW_HELP=false
CONFIGURE_ONLY=false

# Progress tracking
PROGRESS_CURRENT=0
PROGRESS_TOTAL=0

# Function to log and print messages
# 安装/配置函数由 scripts/lib/shell_install.sh 提供
# shellcheck source=lib/shell_install.sh
. "$SCRIPT_DIR/scripts/lib/shell_install.sh"

# Main installation function
main() {
    # Initialize log file
    echo "=== Installation started at $(date) ===" > "$LOG_FILE"

    parse_args "$@"

    if $SHOW_HELP; then
        show_help
        exit 0
    fi

    if $CONFIGURE_ONLY; then
        if $UPDATE_MODE || $CLEAN_BACKUPS; then
            log ERROR "--configure-only cannot be combined with --update or --clean-backups"
            return 1
        fi
        log INFO "Optimizing existing zsh configuration without installing components..."
        apply_zsh_configuration
        log SUCCESS "Zsh configuration updated; open a new terminal to use it"
        return 0
    fi

    if $CLEAN_BACKUPS; then
        clean_backups
        exit 0
    fi

    if $UPDATE_MODE; then
        update_components
        exit 0
    fi

    log INFO "Starting installation..."

    # Calculate total steps for progress indication
    calculate_total_steps
    log INFO "Will execute $PROGRESS_TOTAL installation steps"

    # Check system prerequisites
    log INFO "Checking system prerequisites..."
    if ! check_system_prerequisites; then
        log WARNING "Found $? potential issue(s), but continuing installation"
    fi

    # Check dependencies
    show_progress "Checking dependencies"
    check_dependency git
    check_dependency curl
    if [ "$EUID" -ne 0 ]; then
        check_dependency sudo
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        log INFO "Installing python3 for safe zsh configuration migration..."
        install_package python3
    fi
    if ! $DRY_RUN; then
        check_dependency python3
    fi
    log SUCCESS "All dependencies satisfied"

    # Copy powerlevel10k config if available
    if [ ! -f ~/.p10k.zsh ] && [ -f ./.p10k.zsh ] && ! $NO_P10K; then
        show_progress "Copying powerlevel10k configuration"
        run_cmd cp ./.p10k.zsh ~/.p10k.zsh
    fi

    # Copy .config directory contents
    if [ -d ./.config ] && ! $NO_CONFIG; then
        show_progress "Processing .config directory"
        for item in ./.config/*; do
            if [ -e "$item" ]; then
                item_name=$(basename "$item")
                if [ "$item_name" = fontconfig ]; then
                    log INFO "Configuring explicit Fixedsys font priority..."
                    run_cmd ghostty_install_fontconfig
                    if ! command -v fc-cache >/dev/null 2>&1; then
                        log WARNING "fc-cache not found; run fc-cache -f after installing fontconfig"
                    fi
                else
                    copy_with_backup "$item" "$HOME/.config/$item_name"
                fi
            fi
        done
    fi

    # Install fonts
    if [ -d ./fonts ] && ! $NO_FONTS; then
        show_progress "Installing fonts"
        FONTS_DEST="$HOME/.local/share/fonts"
        if [ ! -d "$FONTS_DEST" ]; then
            log INFO "Creating fonts directory $FONTS_DEST..."
            run_cmd mkdir -p "$FONTS_DEST"
        fi
        for font_file in ./fonts/*; do
            if [ -f "$font_file" ]; then
                font_name=$(basename "$font_file")
                copy_with_backup "$font_file" "$FONTS_DEST/$font_name"
            fi
        done
        if command -v fc-cache &> /dev/null; then
            log INFO "Updating font cache..."
            run_cmd fc-cache -fv
        else
            log WARNING "fc-cache not found, skipping font cache update"
        fi
    fi

    # Install zsh if not present
    if ! command -v zsh &> /dev/null; then
        show_progress "Installing zsh"
        install_zsh
    else
        show_progress "Verifying zsh installation"
        log INFO "zsh is already installed"
    fi

    # Install Oh My Zsh if not present
    show_progress "Installing Oh My Zsh"
    if [ -d "$OMZ_INSTALL_DIR" ]; then
        if [ ! -d "$OMZ_INSTALL_DIR/.git" ]; then
            log WARNING "~/.oh-my-zsh exists but is not a git repository; consider removing it for a clean install"
        fi
        log INFO "Oh My Zsh is already installed"
    else
        install_omz
        log SUCCESS "Oh My Zsh installed successfully"
    fi
    verify_omz_installed

    # Ensure zsh is the default shell (also covers the case where Oh My Zsh was already installed)
    if command -v zsh &> /dev/null && [ "${SHELL:-}" != "$(command -v zsh)" ]; then
        log INFO "Changing default shell to zsh..."
        run_cmd $SUDO_CMD chsh "$(id -un)" -s "$(command -v zsh)"
    fi

    # The final template loads only one prompt theme.
    if ! $NO_P10K; then
        show_progress "Installing powerlevel10k theme"
        git_clone_shallow https://github.com/romkatv/powerlevel10k.git "$PL10K_INSTALL_DIR" "powerlevel10k theme"
    fi

    # Install fzf
    show_progress "Installing fzf"
    git_clone_shallow https://github.com/junegunn/fzf.git ~/.fzf "fzf"
    if [ ! -f ~/.fzf/bin/fzf ]; then
        run_cmd bash "$HOME/.fzf/install" --bin
    fi

    # Install zsh-autosuggestions (skips clone if already bundled with Oh My Zsh)
    show_progress "Installing zsh-autosuggestions"
    install_zsh_plugin https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTOSUGGESTIONS_DIR" "zsh-autosuggestions"

    # Install zsh-syntax-highlighting (skips clone if already bundled with Oh My Zsh)
    show_progress "Installing zsh-syntax-highlighting"
    install_zsh_plugin https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_SYNTAX_HIGHLIGHTING_DIR" "zsh-syntax-highlighting"

    # Try to install fastfetch
    if ! command -v fastfetch &> /dev/null && ! $NO_FASTFETCH; then
        show_progress "Installing fastfetch"
        try_install_fastfetch
    fi

    # Make the Ghostty AppImage use the host's GTK input method modules
    if ! $NO_GHOSTTY_IME; then
        show_progress "Applying Ghostty IME fix"
        fix_ghostty_appimage_ime
    fi

    show_progress "Configuring zsh startup"
    apply_zsh_configuration

    log SUCCESS "Installation complete! Please restart your terminal or log out and log back in for changes to take effect."

    # Run fastfetch if available
    if command -v fastfetch &> /dev/null && ! $NO_FASTFETCH; then
        echo -e "\n${BLUE}Here's your system info:${NC}"
        fastfetch
    fi
}

# Start main execution
main "$@"
