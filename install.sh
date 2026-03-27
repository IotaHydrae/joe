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

# Install zsh using detected package manager
install_zsh() {
    local pkg_manager=$(detect_package_manager)
    log INFO "Installing zsh using $pkg_manager..."
    case "$pkg_manager" in
        apt)
            run_cmd sudo apt update
            run_cmd sudo apt install -y zsh
            ;;
        pacman)
            run_cmd sudo pacman -Syu --noconfirm zsh
            ;;
        dnf)
            run_cmd sudo dnf install -y zsh
            ;;
        zypper)
            run_cmd sudo zypper install -y zsh
            ;;
        *)
            log ERROR "Unsupported package manager $pkg_manager. Please install zsh manually."
            exit 1
            ;;
    esac
    log SUCCESS "zsh installed successfully"
}

# Try to install fastfetch without failing the script
try_install_fastfetch() {
    if $NO_FASTFETCH; then
        log INFO "Skipping fastfetch installation (--no-fastfetch)"
        return
    fi
    
    log INFO "Attempting to install fastfetch..."
    local pkg_manager=$(detect_package_manager)
    case "$pkg_manager" in
        apt)
            run_cmd sudo apt update -y || true
            run_cmd sudo apt install -y fastfetch || true
            ;;
        pacman)
            run_cmd sudo pacman -Syu --noconfirm fastfetch || true
            ;;
        dnf)
            run_cmd sudo dnf install -y fastfetch || true
            ;;
        zypper)
            run_cmd sudo zypper install -y fastfetch || true
            ;;
        *)
            log WARNING "Unsupported package manager, skipping fastfetch installation"
            ;;
    esac
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

# Clean up old backup files
clean_backups() {
    log INFO "Cleaning up old backup files (keeping last $BACKUP_RETENTION)..."
    
    # Clean up backups in ~/.config
    if [ -d ~/.config ]; then
        find ~/.config -name "*.bak.*" -type f -printf '%T+ %p\n' | sort -r | tail -n +$((BACKUP_RETENTION + 1)) | cut -d' ' -f2- | while read -r file; do
            log INFO "Removing old backup: $file"
            run_cmd rm "$file"
        done
    fi
    
    # Clean up backups in ~/.local/share/fonts
    if [ -d ~/.local/share/fonts ]; then
        find ~/.local/share/fonts -name "*.bak.*" -type f -printf '%T+ %p\n' | sort -r | tail -n +$((BACKUP_RETENTION + 1)) | cut -d' ' -f2- | while read -r file; do
            log INFO "Removing old backup: $file"
            run_cmd rm "$file"
        done
    fi
    
    log SUCCESS "Backup cleanup complete"
}

# Update installed components
update_components() {
    log INFO "Updating installed components..."
    
    # Update Oh My Zsh
    if [ -d "$OMZ_INSTALL_DIR" ]; then
        log INFO "Updating Oh My Zsh..."
        run_cmd git -C "$OMZ_INSTALL_DIR" pull --rebase --stat origin master || true
    fi
    
    # Update powerlevel10k
    if [ -d "$PL10K_INSTALL_DIR" ]; then
        log INFO "Updating powerlevel10k..."
        run_cmd git -C "$PL10K_INSTALL_DIR" pull || true
    fi
    
    # Update zsh-autosuggestions
    if [ -d "$ZSH_AUTOSUGGESTIONS_DIR" ]; then
        log INFO "Updating zsh-autosuggestions..."
        run_cmd git -C "$ZSH_AUTOSUGGESTIONS_DIR" pull || true
    fi
    
    # Update zsh-syntax-highlighting
    if [ -d "$ZSH_SYNTAX_HIGHLIGHTING_DIR" ]; then
        log INFO "Updating zsh-syntax-highlighting..."
        run_cmd git -C "$ZSH_SYNTAX_HIGHLIGHTING_DIR" pull || true
    fi
    
    # Update fzf
    if [ -d ~/.fzf ]; then
        log INFO "Updating fzf..."
        run_cmd git -C ~/.fzf pull || true
        run_cmd ~/.fzf/install --bin || true
    fi
    
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
    
    # Create ~/.zshrc if it doesn't exist
    if [ ! -f ~/.zshrc ]; then
        log INFO "Creating ~/.zshrc..."
        run_cmd touch ~/.zshrc
    fi
    
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
    
    # Install powerlevel10k
    if [ ! -d "$PL10K_INSTALL_DIR" ]; then
        log INFO "Installing powerlevel10k theme..."
        run_cmd git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$PL10K_INSTALL_DIR"
    else
        log INFO "powerlevel10k is already installed"
    fi
    
    if ! $NO_P10K; then
        add_source_line "source $PL10K_INSTALL_DIR/powerlevel10k.zsh-theme"
        add_source_line "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh"
    fi
    
    # Install fzf
    if [ ! -d ~/.fzf ]; then
        log INFO "Installing fzf..."
        run_cmd git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        run_cmd bash -c "yes | ~/.fzf/install"
    else
        log INFO "fzf is already installed"
    fi
    
    # Install zsh-autosuggestions
    if [ ! -d "$ZSH_AUTOSUGGESTIONS_DIR" ]; then
        log INFO "Installing zsh-autosuggestions..."
        run_cmd git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTOSUGGESTIONS_DIR"
    else
        log INFO "zsh-autosuggestions is already installed"
    fi
    add_source_line "source $ZSH_AUTOSUGGESTIONS_DIR/zsh-autosuggestions.zsh"
    
    # Install zsh-syntax-highlighting
    if [ ! -d "$ZSH_SYNTAX_HIGHLIGHTING_DIR" ]; then
        log INFO "Installing zsh-syntax-highlighting..."
        run_cmd git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_SYNTAX_HIGHLIGHTING_DIR"
    else
        log INFO "zsh-syntax-highlighting is already installed"
    fi
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
