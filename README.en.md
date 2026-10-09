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
- Installs Oh My Zsh by cloning the repository instead of `curl | sh`, so a failed download can no longer be mistaken for a successful install; the script reports the failure and stops
- Guarantees `.zshrc` actually loads Oh My Zsh: the file is generated from the upstream template when missing, and an existing file without `oh-my-zsh.sh` gets the bootstrap block prepended (the original is backed up first)
- Installs the powerlevel10k theme with a preset configuration
- Installs zsh-autosuggestions (command autosuggestions)
- Installs zsh-syntax-highlighting (syntax highlighting)
- Detects plugins already bundled with Oh My Zsh: if a plugin already exists in `oh-my-zsh/plugins` (or `custom/plugins`), skips cloning it and enables it via `plugins=()` in `.zshrc` instead
- Enables a curated set of bundled plugins (`git`, `sudo`, `extract`, `colored-man-pages`, `colorize`, `z`, `history`, `aliases`, `dirhistory`, `web-search`, `command-not-found`, `you-should-use`), only appending to the existing `plugins=()` — never overwriting it
- Installs fzf (command-line fuzzy finder)
- Optionally installs fastfetch (system information tool)
- Installs custom fonts
- Copies `.config` directory configs; the Ghostty preset disables paste confirmation (`clipboard-paste-protection = false`) and terminal-program clipboard read prompts (`clipboard-read = allow`). Press `Ctrl+Shift+,` to reload after editing
- Fixes Chinese (and other IME) input in the Ghostty AppImage: writes a `<AppImage>.env` next to the AppImage with `GTK_PATH` pointing at a symlink directory of the host's GTK4 input method modules (ibus/fcitx5), so the bundled GTK can load them
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
| `--no-ghostty-ime` | Skip the Ghostty AppImage input method fix |
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

## Component selection

`install_devtools.sh`, `install_mcp_servers.sh`, and `install_skills.sh` open a TUI when run without arguments in an interactive terminal. **Every item starts unchecked.** Select items with Space and confirm with Enter; Enter with no selection or quitting installs nothing. In a non-interactive terminal, specify individual items or `--all`; running without arguments exits with an error.

| Option | Behavior in all three component installers |
|---|---|
| `--tui` | Open the checklist with every item unchecked |
| `--all` | Explicitly install every item; cannot be combined with `--tui` |
| `--list` | List items and their current status |
| `-h, --help` | Show usage and dependencies |

## Devtools suite

The repository ships `install_devtools.sh`, a one-shot installer for a set of common development tools. It is independent of the main `install.sh` and entirely optional. The component list was recorded from the actual setup of a Fedora 44 server so a new machine can reproduce it.

> **Cross-distro support**: the script auto-detects the package manager — **apt** (Debian/Ubuntu), **dnf** (Fedora/RHEL), **pacman** (Arch) and **zypper** (openSUSE). System package names are mapped per distro (e.g. JetBrains Mono is `fonts-jetbrains-mono` on apt, `ttf-jetbrains-mono` on pacman and `jetbrains-mono-fonts` on dnf).

### What gets installed

| Component | Description | How it is installed |
|-----------|-------------|---------------------|
| **Node LTS (installed via nvm)** | Install/switch LTS and migrate existing global packages | nvm loads only during installation; bash/zsh use a fixed PATH |
| **pyenv** | Python version manager; does not install Python automatically | official script + build dependencies, configures bash/zsh |
| **Claude Code** | Anthropic AI CLI (`claude`) | `npm install -g` |
| **Codex CLI** | OpenAI AI CLI (`codex`) | `npm install -g` |
| **Zed editor** | high-performance code editor | official install script + Vulkan drivers |
| **JetBrains Mono font** | code font (used by default in Zed) | system package (mapped per distro) |
| **Ghostty terminal** | modern terminal emulator | dnf: COPR / apt: community deb / pacman: official package |
| **Ctrl+Alt+T shortcut** | quick-open for Ghostty | labwc rc.xml + xdg-terminal-exec |
| **VS Code editor** | Microsoft code editor | official Microsoft repo (dnf/apt/zypper) / pacman: `code` |
| **MiMo Code** | Xiaomi AI coding assistant | `npm install -g` (`@mimo-ai/cli`) |
| **ChatGPT / Codex desktop** | OpenAI official Linux desktop app | official rpm/deb/install script |
| **CC Switch** | AI CLI configuration switcher (desktop) | GitHub release rpm/deb/AppImage |

### Usage

```bash
./install_devtools.sh             # interactive checklist, nothing preselected; non-interactive: specify components
./install_devtools.sh --all       # explicitly install every component
./install_devtools.sh --node      # install/switch Node LTS without loading nvm at shell startup
./install_devtools.sh --python    # pyenv and Python build dependencies only
./install_devtools.sh --ai        # AI CLIs only (claude-code + codex)
./install_devtools.sh --zed       # Zed editor + JetBrains Mono only
./install_devtools.sh --ghostty   # install/repair Ghostty, terminfo and desktop terminal integration
./install_devtools.sh --vscode    # VS Code editor only
./install_devtools.sh --mimo      # MiMo Code only
./install_devtools.sh --chatgpt   # ChatGPT / Codex desktop only
./install_devtools.sh --ccswitch  # CC Switch only
./install_devtools.sh --tui       # interactive checklist (multi-select)
./install_devtools.sh --list      # list installable components and their current status
./install_devtools.sh --help      # full usage and dependency notes
```

### TUI component selection (`--tui`)

Running `./install_devtools.sh --tui` opens a terminal UI for picking components with the keyboard:

- **↑/↓** move the cursor, **Space** toggle a component
- **a** select all, **n** select none, **i** select only uninstalled
- **Enter** start installing, **q** quit
- Every component starts unchecked; installed components are auto-detected, displayed as `[✓装]` and skipped

```bash
./install_devtools.sh --tui
./install_devtools.sh --list      # list components with their install status
```

### Environment variables

- `NODE_LTS` — pin the Node version (default: latest LTS)
- `PROXY_URL` — proxy address, e.g. `http://192.168.50.182:7890` (use when external downloads are slow)

### Notes

- All components are **idempotent**: anything already installed is skipped, so re-running is safe
- `--node` selects the latest Node LTS even when a non-LTS version is already installed, and migrates its global npm packages. Ordinary shells only add `~/.nvm/current/bin` to PATH, without loading `nvm.sh` or its completion. Re-run `--node` to update LTS and the fixed link. Changed shell configs are backed up as `*.bak.<timestamp>` (keeping the latest five)
- `--python` configures pyenv and build dependencies; install your chosen Python version and pipx yourself
- An existing `~/.config/zed/settings.json` is never overwritten (the default font settings are written only when the file is missing)
- The AI CLIs (Claude Code / Codex) still need their own login / API key configuration after installation
- Zed requires Vulkan; the script installs the matching driver per distro (`vulkan-radeon` + `vulkan-intel` on pacman)
- Ghostty checks both user and system `xterm-ghostty` terminfo. When an AppImage keeps it only inside the image, the repair extracts and compiles it with `tic`. Besides `~/.terminfo`, a missing system entry is installed into `/usr/share/terminfo` through `sudo`, fixing `No termcap entry for xterm-ghostty` for both ordinary users and `sudo minicom`. The ncurses tools package provides `infocmp`/`tic`: apt uses `ncurses-bin`, pacman/dnf use `ncurses`, and zypper uses `ncurses-utils`
- Ghostty desktop entries use `~/.local/bin/joe-ghostty`, which passes the caller's directory explicitly as `--working-directory` when reusing a running instance. Cinnamon/Nemo's default terminal points to this launcher too
- Ghostty on Budgie/labwc uses `xdg-terminal-exec`, with an upstream-script fallback when the distro package is unavailable
- Open a new terminal afterwards (or `source ~/.zshrc`)

### zsh startup cost

Node version management runs during installation; ordinary terminals use the fixed runtime path. Load nvm explicitly with `source ~/.nvm/nvm.sh --no-use` when managing versions manually. The Powerlevel10k preset omits the `nvm` segment to avoid calculating a Node executable checksum in every new terminal. Autosuggestions and syntax highlighting load once through Oh My Zsh's `plugins=()`; the saved config no longer sources separate copies or loads an additional robbyrussell theme.

### Repair an existing Ghostty installation

```bash
./repair_ghostty.sh                  # repair; prompts for sudo when system terminfo is missing
infocmp -x xterm-ghostty             # verify the current user's terminal description
sudo infocmp -x xterm-ghostty        # verify the terminal description under sudo
sudo minicom -s                     # verify the minicom setup menu under sudo
```

| Option | Behavior |
|---|---|
| No option | Repair user/system terminfo and desktop integration, using `sudo` when needed |
| `--user-only` | Repair only the current user without `sudo`; cannot install the system entry needed by `sudo minicom` |
| `--help` | Show usage |

Run the repair as your ordinary user so that only the system entry is written through `sudo`; do not run the whole script with `sudo`. It installs no packages and preserves Ghostty font, theme and keybinding preferences. Changed launchers, desktop entries, terminal preference lists and Cinnamon settings are backed up as `*.bak.<timestamp>` (keeping the latest five). Desktop entries are found in user directories before system directories, and other terminals remain in the fallback list. Repeated repairs leave unchanged files untouched. `doctor.sh` checks user and system terminfo separately, so a user-only entry does not count as a complete repair.

## MCP servers

`install_mcp_servers.sh` configures the installed Claude Code, Codex CLI, and MiMo Code clients. Claude uses the user scope, Codex writes its CLI configuration, and MiMo uses `~/.config/mimocode/mimocode.jsonc`.

| Server | Runtime |
|---|---|
| `filesystem` | `npx @modelcontextprotocol/server-filesystem` |
| `git` | `uvx mcp-server-git` |
| `memory` | `npx @modelcontextprotocol/server-memory` |
| `codebase-memory-mcp` | Official static binary |
| `context7` | `npx @upstash/context7-mcp` |
| `codegraph` | `@astudioplus/codegraph-mcp` and its engine |
| `serena` | `uvx --from serena-agent serena start-mcp-server` |

```bash
./install_mcp_servers.sh             # checklist, nothing preselected
./install_mcp_servers.sh memory git  # install only these servers
./install_mcp_servers.sh --all       # explicitly install every server
./install_mcp_servers.sh --list
```

A server is marked installed in the TUI only when every installed client has its configuration, so newly installed clients can be configured too. Each client skips servers it already has. Claude/MiMo configuration checks require `python3`; CLI registration failures return a nonzero exit code. Invalid MiMo configuration is preserved. Successful edits create `*.bak.<timestamp>` backups (keeping the latest five) and replace the file atomically. JSONC comments are converted to standard JSON while string contents are preserved.

Filesystem access defaults to `$HOME` and `/tmp`; override it with `FILESYSTEM_DIRS="/home/dev /data /projects"`. `CBM_VARIANT=ui` selects the codebase-memory visual variant, and `PROXY_URL` sets the download proxy.

## Agent skills

```bash
./install_skills.sh          # checklist, nothing preselected
./install_skills.sh joe-env  # install/update only this skill
./install_skills.sh engineering-embedded-linux-driver-engineer  # embedded Linux drivers only
./install_skills.sh --all    # explicitly install/update every skill
./install_skills.sh --list
./install_skills.sh --categories
./install_skills.sh --category kernel-dev --tui  # browse a category; nothing preselected
./install_skills.sh --category kernel-dev --all  # explicitly install the entire category
```

Skills and their supporting directories are copied to `~/.agents/skills` and the detected clients' skill directories. Items already current in every target are skipped. All three TUIs use arrows to move, PgUp/PgDn to move by a page, Home/End to move to the first/last item, Space to select, `a` to select all missing items, `n` to clear the selection, `i` to select only missing items, Enter to install, and `q` to quit. Lists fit the terminal height; the skill selector displays each item's category.

Repeat `--category` to combine categories. It filters `--list`, `--tui`, `--all`, and explicit skill names regardless of argument order. Filtering leaves all items unchecked; non-interactive installation requires skill names or `--all`. Existing and custom skills belong to `local`.

| Option | Purpose |
|---|---|
| `--categories` | List categories and skill counts |
| `--category <name>` | Filter by category; repeatable; metadata comes from `skills/categories.tsv` |

The bundled `engineering-embedded-linux-driver-engineer` skill covers embedded Linux kernel drivers and BSP development: Device Tree, Platform/I2C/SPI/USB, DMA/interrupts, and Yocto/Buildroot. It comes from [clowlove/hermes-house](https://www.skills.sh/clowlove/hermes-house/engineering-embedded-linux-driver-engineer), with the upstream `SKILL.md` and `skill.json` preserved, the MIT license included, and the [source revision recorded](skills/engineering-embedded-linux-driver-engineer/SOURCE.md). Select it in the TUI or specify its name explicitly to install it.

The repository also bundles **142 skills in 25 categories** from [mohitmishra786/low-level-dev-skills](https://github.com/mohitmishra786/low-level-dev-skills): compilers, debuggers, profilers, Linux kernel drivers, bare-metal programming, Rust, Zig, GPU development, and more. See the [complete catalog](skills/low-level-dev-skills.md). Each skill includes its reference files, the MIT license, and a `SOURCE.md` recording the pinned upstream commit. Cross-skill references use joe's directory layout. Related skills and system tools are installed separately as needed.

For embedded Linux development:

```bash
./install_skills.sh --category kernel-dev --category kernel --tui
./install_skills.sh --category embedded --category baremetal --tui
./install_skills.sh --category compilers --category debuggers --tui
./install_skills.sh device-tree bus-drivers-i2c-spi gdb cross-gcc
```

## Bootstrap and updates

```bash
./bootstrap.sh                    # each installer opens an empty checklist
./bootstrap.sh --only mcp,skills   # run selected stages
./bootstrap.sh --yes               # explicitly install everything without a TUI
./update-all.sh                    # update installed tools and MCP engines
./update-all.sh --dry-run          # preview updates
./update-all.sh --system           # also update system packages
```

The updater no longer runs the MCP or skill installers automatically. Run the corresponding installer to select MCP configuration or skill updates. `bootstrap.sh --yes` passes `--all` explicitly to each component installer.

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
10. **Ghostty AppImage input method fix** — when a Ghostty AppImage is found in `~/.local/bin` (or `~/Applications`), an `<AppImage>.env` is written with `GTK_PATH` pointing at a symlink directory of the host's GTK4 input method modules (override the path with `GHOSTTY_APPIMAGE`, skip with `--no-ghostty-ime`)

## Notes

- The script automatically backs up existing config files as `.bak.<timestamp>`
- The last 5 backups are kept by default
- The script verifies that Oh My Zsh really got installed and aborts otherwise, so it never leaves a `.zshrc` with only a few `source` lines behind
- If your `.zshrc` contains only `source ...` fragments (no `export ZSH=`, `plugins=()` or `source $ZSH/oh-my-zsh.sh`), simply re-run `./install.sh` to repair it
- The Ghostty AppImage input method fix is tied to the AppImage file name (the runtime reads a `.env` file with the same name); after switching to a new version with a different file name, re-run `./install.sh` to point it at the new file, and restart any running Ghostty windows for it to take effect
- Restart your terminal or log out and back in after installation for the changes to take effect
