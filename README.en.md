# Joe

> [中文](README.md) | **English**

An automated zsh environment setup script, including Oh My Zsh, the powerlevel10k theme, and common plugins.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/IotaHydrae/joe/main/install.sh | bash
```

> Note: The one-liner first clones the repository to `~/.joe` and then runs install.sh from inside it, so repo-local assets such as `.config`, `fonts`, and `.p10k.zsh` are installed as well. An existing `~/.joe` clone is reused (override the location with the `JOE_INSTALL_DIR` environment variable).

## Features

- Automatically installs zsh (supports apt/pacman/dnf/zypper package managers)
- Installs and configures Oh My Zsh
- Installs the powerlevel10k theme with a preset configuration
- Installs zsh-autosuggestions (command autosuggestions)
- Installs zsh-syntax-highlighting (syntax highlighting)
- Detects plugins already bundled with Oh My Zsh: if a plugin already exists in `oh-my-zsh/plugins` (or `custom/plugins`), skips cloning it and enables it via `plugins=()` in `.zshrc` instead
- Enables a curated set of bundled plugins (`git`, `sudo`, `extract`, `colored-man-pages`, `colorize`, `z`, `history`, `aliases`, `dirhistory`, `web-search`, `command-not-found`, `you-should-use`), only appending to the existing `plugins=()` — never overwriting it
- Installs fzf (command-line fuzzy finder)
- Optionally installs fastfetch (system information tool)
- Installs custom fonts
- Copies `.config` directory configs (e.g. ghostty terminal)
- Automatically backs up existing config files
- Supports component update mode
- Supports cleaning up old backups

## Installation & Usage

### Basic installation

```bash
./install.sh
```

### Command-line options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show this help message and exit |
| `-n, --dry-run` | Simulate the installation without making changes |
| `--no-fonts` | Skip font installation |
| `--no-config` | Skip copying the `.config` directory |
| `--no-p10k` | Skip powerlevel10k configuration |
| `--no-fastfetch` | Skip fastfetch installation |
| `--no-default-plugins` | Skip enabling the default plugins |
| `--clean-backups` | Clean up old backup files (keeps the last 5) |
| `-u, --update` | Update installed components instead of installing |

### Usage examples

```bash
# Simulate the installation to preview what it will do
./install.sh --dry-run

# Install without installing fonts
./install.sh --no-fonts

# Update installed components
./install.sh --update

# Clean up old backups
./install.sh --clean-backups
```

## What Gets Installed

### Dependencies

- git, curl (sudo is also required for non-root users)
- fc-cache (optional; the font cache update is skipped if it is missing)

### Installed components

1. **zsh** — installed automatically via the system package manager if missing
2. **Oh My Zsh** — zsh configuration framework
3. **powerlevel10k** — fast, customizable zsh theme
4. **fzf** — command-line fuzzy finder
5. **zsh-autosuggestions** — suggests commands based on history
6. **zsh-syntax-highlighting** — command syntax highlighting
7. **fastfetch** — system information tool (optional)
8. **Custom fonts** — e.g. Fixedsys (optional)
9. **Config files** — contents of the `.config` directory (e.g. ghostty terminal)

## Notes

- The script automatically backs up existing config files as `.bak.<timestamp>`
- The last 5 backups are kept by default
- Restart your terminal or log out and back in after installation for the changes to take effect
