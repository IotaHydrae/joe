#!/bin/bash
# We assume you're using bash

set -euo pipefail

# Configuration and constants
OMZ_INSTALL_DIR=~/.oh-my-zsh
PL10K_INSTALL_DIR=~/.powerlevel10k
ZSH_AUTOSUGGESTIONS_DIR=~/.zsh-autosuggestions
ZSH_SYNTAX_HIGHLIGHTING_DIR=~/.zsh-syntax-highlighting
LOG_FILE="install.log"
BACKUP_RETENTION=5

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Command line flags
DRY_RUN=false
NO_FONTS=false
NO_CONFIG=false
NO_P10K=false
NO_FASTFETCH=false
CLEAN_BACKUPS=false
UPDATE_MODE=false
SHOW_HELP=false

# Function to log and print messages
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    # Log to file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    # Print to console with colors
    case "$level" in
        INFO)
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        WARNING)
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
    esac
}

# Function to print help message
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Installs and configures zsh with Oh My Zsh, powerlevel10k, and other tools.

Options:
    -h, --help              Show this help message and exit
    -n, --dry-run           Simulate installation without making changes
    --no-fonts              Skip font installation
    --no-config             Skip .config directory copying
    --no-p10k               Skip powerlevel10k configuration
    --no-fastfetch          Skip fastfetch installation and execution
    --clean-backups         Clean up old backup files (keeps last $BACKUP_RETENTION)
    -u, --update            Update installed components instead of installing
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                SHOW_HELP=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                log INFO "Dry run mode enabled - no changes will be made"
                shift
                ;;
            --no-fonts)
                NO_FONTS=true
                shift
                ;;
            --no-config)
                NO_CONFIG=true
                shift
                ;;
            --no-p10k)
                NO_P10K=true
                shift
                ;;
            --no-fastfetch)
                NO_FASTFETCH=true
                shift
                ;;
            --clean-backups)
                CLEAN_BACKUPS=true
                shift
                ;;
            -u|--update)
                UPDATE_MODE=true
                shift
                ;;
            *)
                log ERROR "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Execute command or just log if dry run
run_cmd() {
    if $DRY_RUN; then
        log INFO "Dry run: Would execute: $*"
    else
        "$@"
    fi
}

# Check if a command exists
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        log ERROR "$1 is not installed. Please install $1 first."
        exit 1
    fi
}

# Detect package manager
detect_package_manager() {
    if command -v apt &> /dev/null; then
        echo "apt"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v zypper &> /dev/null; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

# Install package using detected package manager
install_package() {
    local package="$1"
    local pkg_manager=$(detect_package_manager)
    log INFO "Installing $package using $pkg_manager..."
    case "$pkg_manager" in
        apt)
            run_cmd sudo apt update
            run_cmd sudo apt install -y "$package"
            ;;
        pacman)
            run_cmd sudo pacman -Syu --noconfirm "$package"
            ;;
        dnf)
            run_cmd sudo dnf install -y "$package"
            ;;
        zypper)
            run_cmd sudo zypper install -y "$package"
            ;;
        *)
            log ERROR "Unsupported package manager $pkg_manager. Please install $package manually."
            return 1
            ;;
    esac
    log SUCCESS "$package installed successfully"
}

# Try to install package without failing
try_install_package() {
    local package="$1"
    local pkg_manager=$(detect_package_manager)
    case "$pkg_manager" in
        apt)
            run_cmd sudo apt update -y || true
            run_cmd sudo apt install -y "$package" || true
            ;;
        pacman)
            run_cmd sudo pacman -Syu --noconfirm "$package" || true
            ;;
        dnf)
            run_cmd sudo dnf install -y "$package" || true
            ;;
        zypper)
            run_cmd sudo zypper install -y "$package" || true
            ;;
        *)
            log WARNING "Unsupported package manager, skipping $package installation"
            ;;
    esac
}

# Install zsh
install_zsh() {
    install_package zsh
}

# Try to install fastfetch without failing the script
try_install_fastfetch() {
    if $NO_FASTFETCH; then
        log INFO "Skipping fastfetch installation (--no-fastfetch)"
        return
    fi

    log INFO "Attempting to install fastfetch..."
    try_install_package fastfetch
}

# Copy files/directories with backup
copy_with_backup() {
    local src="$1"
    local dest="$2"

    if [ -e "$dest" ]; then
        local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
        log INFO "Backing up existing $dest to $backup"
        run_cmd mv "$dest" "$backup"
    fi

    local dest_dir=$(dirname "$dest")
    if [ ! -d "$dest_dir" ]; then
        log INFO "Creating directory $dest_dir"
        run_cmd mkdir -p "$dest_dir"
    fi

    log INFO "Copying $src to $dest"
    run_cmd cp -r "$src" "$dest"
}

# Add a line to ~/.zshrc if it doesn't already exist
add_source_line() {
    local line="$1"
    if ! grep -qxF "$line" ~/.zshrc 2>/dev/null; then
        log INFO "Adding '$line' to ~/.zshrc"
        run_cmd bash -c "echo '$line' >> ~/.zshrc"
    else
        log INFO "'$line' already exists in ~/.zshrc"
    fi
}

# Clean up old backup files in a directory
clean_backups_in_dir() {
    local dir="$1"
    if [ -d "$dir" ]; then
        find "$dir" -name "*.bak.*" -type f -printf '%T+ %p\n' | sort -r | tail -n +$((BACKUP_RETENTION + 1)) | cut -d' ' -f2- | while read -r file; do
            log INFO "Removing old backup: $file"
            run_cmd rm "$file"
        done
    fi
}

# Clean up old backup files
clean_backups() {
    log INFO "Cleaning up old backup files (keeping last $BACKUP_RETENTION)..."

    clean_backups_in_dir ~/.config
    clean_backups_in_dir ~/.local/share/fonts

    log SUCCESS "Backup cleanup complete"
}

# Clone git repo if not exists
git_clone_shallow() {
    local repo_url="$1"
    local target_dir="$2"
    local name="$3"

    if [ ! -d "$target_dir" ]; then
        log INFO "Installing $name..."
        run_cmd git clone --depth=1 "$repo_url" "$target_dir"
    else
        log INFO "$name is already installed"
    fi
}

# Update git repo
git_update_repo() {
    local repo_dir="$1"
    local name="$2"
    local extra_cmd="$3"

    if [ -d "$repo_dir" ]; then
        log INFO "Updating $name..."
        run_cmd git -C "$repo_dir" pull || true
        if [ -n "$extra_cmd" ]; then
            run_cmd $extra_cmd || true
        fi
    fi
}

# Update installed components
update_components() {
    log INFO "Updating installed components..."

    git_update_repo "$OMZ_INSTALL_DIR" "Oh My Zsh" "git -C $OMZ_INSTALL_DIR pull --rebase --stat origin master"
    git_update_repo "$PL10K_INSTALL_DIR" "powerlevel10k"
    git_update_repo "$ZSH_AUTOSUGGESTIONS_DIR" "zsh-autosuggestions"
    git_update_repo "$ZSH_SYNTAX_HIGHLIGHTING_DIR" "zsh-syntax-highlighting"
    git_update_repo ~/.fzf "fzf" "~/.fzf/install --bin"

    log SUCCESS "Components update complete"
}

# Main installation function
main() {
    # Initialize log file
    echo "=== Installation started at $(date) ===" > "$LOG_FILE"

    parse_args "$@"

    if $SHOW_HELP; then
        show_help
        exit 0
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

    # Check dependencies
    log INFO "Checking dependencies..."
    check_dependency git
    check_dependency curl
    log SUCCESS "All dependencies satisfied"

    # Copy powerlevel10k config if available
    if [ ! -f ~/.p10k.zsh ] && [ -f ./.p10k.zsh ] && ! $NO_P10K; then
        log INFO "Copying .p10k.zsh to ~/.p10k.zsh..."
        run_cmd cp ./.p10k.zsh ~/.p10k.zsh
    fi

    # Copy .config directory contents
    if [ -d ./.config ] && ! $NO_CONFIG; then
        log INFO "Processing .config directory..."
        for item in ./.config/*; do
            if [ -e "$item" ]; then
                item_name=$(basename "$item")
                copy_with_backup "$item" "$HOME/.config/$item_name"
            fi
        done
    fi

    # Install fonts
    if [ -d ./fonts ] && ! $NO_FONTS; then
        log INFO "Processing fonts directory..."
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
        log INFO "Updating font cache..."
        run_cmd fc-cache -fv
    fi

    # Install zsh if not present
    if ! command -v zsh &> /dev/null; then
        install_zsh
    else
        log INFO "zsh is already installed"
    fi

    # Install Oh My Zsh if not present
    if [ -d "$OMZ_INSTALL_DIR" ]; then
        log INFO "Oh My Zsh is already installed"
    else
        log INFO "Installing Oh My Zsh..."
        run_cmd bash -c "CHSH=no RUNZSH=no KEEP_ZSHRC=yes sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
        log INFO "Changing default shell to zsh..."
        run_cmd sudo chsh "$USER" -s "$(command -v zsh)"
        log SUCCESS "Oh My Zsh installed successfully"
    fi

    # Create ~/.zshrc as fallback if OMZ didn't create one
    if [ ! -f ~/.zshrc ]; then
        log INFO "Creating ~/.zshrc (OMZ template was not generated)..."
        run_cmd touch ~/.zshrc
    fi

    # Install powerlevel10k
    git_clone_shallow https://github.com/romkatv/powerlevel10k.git "$PL10K_INSTALL_DIR" "powerlevel10k theme"

    if ! $NO_P10K; then
        add_source_line "source $PL10K_INSTALL_DIR/powerlevel10k.zsh-theme"
        add_source_line "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh"
    fi

    # Install fzf
    git_clone_shallow https://github.com/junegunn/fzf.git ~/.fzf "fzf"
    if [ ! -f ~/.fzf/bin/fzf ]; then
        run_cmd bash -c "yes | ~/.fzf/install"
    fi

    # Install zsh-autosuggestions
    git_clone_shallow https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTOSUGGESTIONS_DIR" "zsh-autosuggestions"
    add_source_line "source $ZSH_AUTOSUGGESTIONS_DIR/zsh-autosuggestions.zsh"

    # Install zsh-syntax-highlighting
    git_clone_shallow https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_SYNTAX_HIGHLIGHTING_DIR" "zsh-syntax-highlighting"
    add_source_line "source $ZSH_SYNTAX_HIGHLIGHTING_DIR/zsh-syntax-highlighting.zsh"

    # Try to install fastfetch
    if ! command -v fastfetch &> /dev/null && ! $NO_FASTFETCH; then
        try_install_fastfetch
    fi

    log SUCCESS "Installation complete! Please restart your terminal or log out and log back in for changes to take effect."

    # Run fastfetch if available
    if command -v fastfetch &> /dev/null && ! $NO_FASTFETCH; then
        echo -e "\n${BLUE}Here's your system info:${NC}"
        fastfetch
    fi
}

# Start main execution
main "$@"
