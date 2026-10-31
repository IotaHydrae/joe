# Joe

> [中文](README.md) | **English**

Automated development environment setup: terminal beautification (zsh + Oh My Zsh), development tools installation, and AI coding assistant integration.

## Quick Start

### One-line Installation
```bash
curl -fsSL https://raw.githubusercontent.com/IotaHydrae/joe/main/install.sh | bash
```

Clones to `~/.joe` and opens a menu to select components.

### Local Installation
```bash
git clone https://github.com/IotaHydrae/joe.git
cd joe
./install.sh
```

## Main Features

### 1. Terminal Beautification (Shell)
- **zsh** + **Oh My Zsh** automatic installation and configuration
- **powerlevel10k** theme (elegant command-line prompt)
- **Common plugins**: auto-completion, syntax highlighting, fzf fuzzy search, etc.
- **Auto-backup**: backs up original config before changes, keeps last 5

Main menu item 1 and the `shell` command apply the same optimized zsh configuration. Fresh setups enable six OMZ plugins: `git sudo extract z history dirhistory`. The theme uses installed powerlevel10k or robbyrussell. Autosuggestions run asynchronously, syntax highlighting loads last, and fzf loads its existing completion and key-binding scripts directly. Node/Python use static PATH entries; version-manager integration loads when `nvm` / `pyenv` is first invoked. OMZ automatic update checks are disabled; use `./install.sh shell --update` to update explicitly.

Existing aliases, custom PATH entries, proxy settings, and plugin choices are preserved. Personal settings live in the user block of `.zshrc` or in `~/.zshrc.local`. Use `--configure-only` to apply the configuration offline. Changed files are backed up as `.zshrc.bak.<timestamp>`, keeping the latest five; identical contents are left untouched.

```bash
./install.sh shell                              # Full installation with optimized config
./install.sh shell --dry-run                    # Preview operations
./install.sh shell --configure-only             # Update zsh config offline only
./install.sh shell --configure-only --dry-run   # Preview config migration
./install.sh shell --no-fonts                   # Skip fonts
```

### Font Installation (Fonts)

Main menu item 6 (fonts), or `./install.sh fonts`, opens a numbered submenu with Fixedsys Excelsior (FSEX302) and JetBrains Mono, installed status, individual or all-font installation, and `b` to return to the main menu. After installation, the current submenu stays open.

Fonts are installed from the repository into `~/.local/share/fonts`, work offline, and require no sudo. JetBrains Mono 2.304 includes regular, bold, italic, and bold italic styles with its [SIL OFL license](fonts/jetbrains-mono/OFL.txt). The `shell` command installs Fixedsys Excelsior by default; JetBrains Mono is available separately from the fonts menu.

```bash
./install.sh fonts list                           # List fonts and installed status
./install.sh fonts install fsex302                # Install Fixedsys Excelsior
./install.sh fonts install jetbrains-mono         # Install JetBrains Mono
./install.sh fonts install --all                  # Install all fonts
./install.sh fonts install --dry-run --all        # Preview installation
```

### 2. Development Tools (Devtools)
Cross-distro development tools installation (supports apt/pacman/dnf/zypper):

Main menu item 3 (development tools) uses the same numbered list as item 2 (daily apps): installed status, individual or all-component installation, and `b` to return to the main menu. After installation, the current submenu stays open.

- **Node.js**: nvm + LTS version
- **Python**: pyenv (doesn't pre-install Python, you choose the version)
- **AI CLI**: Claude Code, Codex (`--ai` installs only these two), Gemini CLI, OpenCode, GitHub Copilot CLI, Grok Build
- **Editors**: Zed, VS Code
- **Terminal**: Ghostty
- **Game Engine**: Latest official stable Godot release (x86_64 / ARM64), verified with SHA-512. Run `./install.sh tools install godot` to install or upgrade; skips the download when already current
- **Others**: MiMo Code, CC Switch
- **Daily apps**: Brave Browser, ChatGPT Desktop, official Linux WeChat and QQ, Rime input method (rime-ice). Main menu item 2, or `./install.sh tools install brave` / `chatgpt` / `wechat` / `qq` / `rime`. Not included in `devtools --all`, `tools install --all`, or `quick-start --yes`

Linux QQ reads the package URL from the official configuration and requests a temporary signed download link from the official API before downloading, avoiding HTTP 403 on unsigned links. Installation stops if signing or validation fails.

WeChat and QQ packages support resumable downloads: connection failures are retried automatically, and unfinished downloads are kept for the next run of the same install command (QQ obtains a fresh signature). The cache is stored in `${XDG_CACHE_HOME:-~/.cache}/joe/downloads` and removed after successful installation. Changed files or servers without resume support trigger a fresh download; failed integrity checks prevent installation. Requires `flock` (util-linux).

```bash
# ===== New syntax (recommended) =====
./install.sh tools                     # TUI interactive selection
./install.sh tools list                # List all components and status
./install.sh tools install node        # Install Node.js
./install.sh tools install claude      # Install Claude Code (prompts for deps)
./install.sh tools install --ai        # Install the AI group (Claude + Codex)
./install.sh tools install claude codex gemini  # Several at once
./install.sh tools update              # Update everything (official self-updaters)
./install.sh tools update claude node  # Update only the given components
./install.sh tools update --dry-run    # Preview what would run

# ===== Legacy syntax (still works) =====
./install.sh devtools              # TUI interactive selection
./install.sh devtools --list       # List all components
./install.sh devtools --node       # Install Node.js only
./install.sh devtools --python     # Install pyenv only
./install.sh devtools --claude     # Install Claude Code only
./install.sh devtools --codex      # Install Codex CLI only
./install.sh devtools --ai         # Install Claude Code and Codex
./install.sh devtools --gemini     # Install Gemini CLI only
./install.sh devtools --opencode   # Install OpenCode only
./install.sh devtools --copilot    # Install GitHub Copilot CLI only
./install.sh devtools --grok       # Install Grok Build only
```

`tools update <id...>` forwards `--only` to `update-all.sh`. Components without
a self-update path (Zed, VS Code, Ghostty, Brave) are rejected with the matching
`tools install <id>` command instead of being silently skipped.

### 3. MCP Servers
Install Model Context Protocol servers for AI coding assistants:

Main menu item 4 (MCP servers) also uses a numbered list with configured status, individual or all-server installation, and `b` to return. Code intelligence services are marked as alternatives (choose one), and Node/npx is checked before installation.

- **filesystem** / **git**: File and code management
- **memory**: Conversation memory
- **context7**: Real-time documentation lookup
- **Code Intelligence**: codebase-memory-mcp, codegraph, serena (choose one)

Installed Gemini CLI, OpenCode, Grok Build, Zed, and VS Code receive the same MCP entries. Copilot CLI uses `copilot mcp add`. `filesystem` requires `FILESYSTEM_DIRS`. Running `./install.sh mcp <id>` again updates an entry when its command changes.

```bash
# ===== New syntax (recommended) =====
./install.sh mcp                   # TUI interactive selection
./install.sh mcp list              # List all MCPs and their status
./install.sh mcp install memory git  # Install specified servers
./install.sh mcp update filesystem # Re-run the installer to refresh one entry

# ===== Legacy syntax (still works) =====
./install.sh mcp --list            # = mcp list
./install.sh mcp memory git        # still supported
```

The `./install.sh mcp` TUI groups servers into files/repos, memory/docs and code
intelligence (pick one), shows whether each entry is already configured in the
installed AI CLIs, and reports the Node/npx dependency in the status bar. When
npx is missing it tells you to run `./install.sh tools install node` first.

**Tip**: When first using code intelligence MCPs, tell the AI to "index this project".

### 4. Agent Skills
Add professional skill templates for AI assistants:

- **Code Exploration**: Cross-project code navigation
- **Code Quality**: Code review standards
- **Repository Exploration**: Quickly understand new projects
- **Testing**: Testing strategies and implementation
- **Embedded**: Boot optimization and specialized skills
- **low-level-dev-skills**: 142 low-level development skills across 25 categories

```bash
./install.sh skills                # Skill group → category → checklist
./install.sh skills list           # List skills and installation status
./install.sh skills categories     # List categories and skill counts
./install.sh skills install gdb    # Install GDB skill only
./install.sh skills gdb            # Legacy syntax, same result
./install.sh skills --category kernel-dev --tui  # Open the kernel driver category directly
```

The skills menu separates existing/local skills (8) from low-level-dev-skills (142 skills in 25 categories). Choose a category, then select individual skills; nothing is preselected. Enter a number to open a submenu; `b`/`q` goes back one level. Installing or leaving a checklist returns to the current menu so you can choose another category. With `--category`, the installer opens a filtered checklist directly and exits afterward. Non-interactive installation requires skill names or an explicit `--all`.

The only real copy lives in `~/.agents/skills`. Claude Code, Codex, Gemini, OpenCode, Grok Build, MiMo, and Copilot skill directories are symlinks to that copy.

## Common Commands

```bash
./install.sh                   # Main menu
./install.sh fonts list        # List fonts and status
./install.sh tools list        # List tools and status
./install.sh mcp list          # List MCP servers
./install.sh status            # One-screen summary of tools / MCP / skills
./install.sh status --short    # Single line, for scripts
./install.sh doctor            # Environment check
./install.sh --help            # Help
```

## Troubleshooting

- [Troubleshooting guide](docs/TROUBLESHOOTING.md) - common problems and fixes
- [Ghostty terminal fix](docs/GHOSTTY_FIX.md) - terminfo, desktop integration, and Fixedsys font priority
- [Migration guide](docs/MIGRATION.md) - 1.x to 2.0

Quick Ghostty fix:
```bash
./install.sh repair-ghostty              # Repair terminfo, desktop integration, and Fixedsys font priority
./install.sh repair-ghostty --user-only  # Current user only; do not write system terminfo
```

The repair command and `./install.sh tools install ghostty` deploy a user font rule at `${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/conf.d/99-fixedsys-explicit.conf`. The `shell` configuration step also merges this rule while preserving other user font rules; `--no-config` skips it. Only when an application explicitly requests `Fixedsys Excelsior`, the rule sets the family order to Fixedsys → Noto Sans Mono CJK SC → Noto Color Emoji and removes the generic `monospace` entry from that request. This prevents Chinese language rules from taking priority over Fixedsys; other families and ordinary `monospace` requests are unaffected.

Changed rules are backed up, keeping the latest five backups, and the font cache is refreshed when `fc-cache` is available. Missing fallback fonts are not installed. Restart Ghostty afterward and verify Latin text, Chinese, and emoji under the same `zh_CN.UTF-8` locale as the desktop; see the [font repair guide](docs/GHOSTTY_FIX.md#fixedsys-字体优先级修复).

The repair also updates `~/.local/bin/joe-ghostty`: each window starts a separate process so it loads the currently installed input-method module; on X11 with `wmctrl`, it activates only newly created Ghostty windows, using `xprop` to confirm focus and briefly retry rejected requests; Wayland keeps native focus behavior. Existing Cinnamon custom shortcuts that directly execute `ghostty` are backed up and migrated to this launcher, and Cinnamon's cached shortcut commands are refreshed immediately. Other custom commands and global focus settings are preserved.

## Maintenance Commands

```bash
# Install everything (recommended for new machines, asks for confirmation)
./install.sh install-all
./install.sh quick-start            # Guided deploy: shell/tools/MCP/skills/doctor
./install.sh quick-start --yes      # Non-interactive, install everything
./install.sh quick-start --skip shell   # Drop one stage

# Environment check
./install.sh doctor                  # Check installation status
./install.sh doctor --quiet          # Show problems only

# Update
./install.sh update                  # Update installed components

# Config sync
./install.sh config list             # Show the config mapping
./install.sh config export           # Export this machine's config
```

## Options

### Shell Options
```bash
--dry-run              # Simulate run without actual changes
--configure-only       # Update zsh config offline only; no packages, downloads, default-shell changes, or fonts/.config copies
--no-fonts             # Skip font installation
--no-config            # Skip .config copy
--no-p10k              # Skip powerlevel10k
--no-fastfetch         # Skip fastfetch
--no-default-plugins   # Fresh config enables only git; preserve existing plugin choices
--clean-backups        # Clean old backups (keep last 5)
-u, --update           # Update installed components
```

### Fonts Options

| Option | Purpose |
|---|---|
| `list` / `status` | List fonts and installed status without making changes |
| `install fsex302` | Install Fixedsys Excelsior (FSEX302) |
| `install jetbrains-mono` | Install JetBrains Mono; multiple font ids can be supplied together |
| `install --all` | Explicitly install all fonts |
| `install --dry-run <id...>` / `install --dry-run --all` | Preview installation without changing files or the font cache |
| `--help` | Show font command help |

### Devtools Options
```bash
--tui                  # Force TUI selection interface
--list                 # List all components and status
--node                 # Install Node.js toolchain only
--python               # Install Python toolchain only
--claude               # Install Claude Code only
--codex                # Install Codex CLI only
--ai                   # Install Claude Code and Codex
--gemini               # Install Gemini CLI only
--opencode             # Install OpenCode only
--copilot              # Install GitHub Copilot CLI only
--grok                 # Install Grok Build only
--zed                  # Install Zed editor only
--vscode               # Install VS Code only
--ghostty              # Install Ghostty terminal only
--brave                # Install Brave browser only
--mimo                 # Install MiMo Code only
--chatgpt              # Install ChatGPT Desktop only
--ccswitch             # Install CC Switch only
--godot                # Install/update the latest official stable Godot release
--wechat               # Install official Linux WeChat only
--qq                   # Install official Linux QQ only
--rime                 # Install/repair Rime (rime-ice), preserving personal dictionaries
```

Run `./install.sh tools install rime` again (or select Rime in main menu item 2) to repair an existing installation. It installs the Fcitx 5 GTK/Qt frontends and Rime Lua plugin, recompiles rime-ice, merges the input-method list and left Alt+Shift shortcuts, and selects Fcitx 5 through `im-config` when available. Personal dictionaries, other input methods, and unrelated environment variables are preserved. Changed configuration is backed up, keeping the latest five copies.

Deployment failures are reported; incomplete existing dictionary directories are preserved for recovery. In a desktop session, the old Fcitx 4 daemon exits gracefully and Fcitx 5 restarts; old packages are not automatically removed. Close and reopen existing applications such as Ghostty so they can load the newly installed input-method module. `doctor` checks the compiled rime-ice files and input-method list, and warns about login configuration that still selects Fcitx 4 or a remaining old daemon.

### MCP Options
```bash
--tui                  # Force TUI selection interface
--list                 # List all MCP servers
filesystem git         # Install specified MCPs (supports multiple)
list / install / update  # New action syntax, equivalent to the options above
```

### Skills Options

| Option | Purpose |
|---|---|
| `--tui` | Open group/category submenus; with `--category`, open a filtered checklist directly |
| `--list` | List skills and installation status |
| `--categories` | List categories and skill counts |
| `--category <name>` | Filter by category; repeat to combine categories; supports `--list`, `--tui`, `--all` and skill names |
| `--all` | Explicitly install all skills, limited to selected categories when filters are supplied |
| `list` / `categories` / `install <skill>` | New action syntax, equivalent to `--list` / `--categories` / positional skill names |

Categories and counts come from `skills/categories.tsv` and the skill directories. Existing and custom skills belong to `local`. See the [low-level-dev-skills catalog](skills/low-level-dev-skills.md).

## System Support

Requires bash >= 4.4 (empty-array expansion under `set -u`) plus GNU coreutils/findutils.

Verified distributions:

| Distribution | Package Manager | Status |
|--------------|----------------|--------|
| Ubuntu 24.04 / 22.04 | apt | ✅ |
| Linux Mint 22.3 | apt | ✅ |
| Arch Linux / CachyOS | pacman | ✅ |
| Fedora | dnf | ✅ |
| openSUSE | zypper | ✅ |

## FAQ

### No Python after pyenv installation?
This is normal, you need to manually select a version:
```bash
pyenv install --list      # View available versions
pyenv install 3.12.0      # Install specific version
pyenv global 3.12.0       # Set as global version
```

### MCP servers not working?
1. Check connection status: `claude mcp list` (or `codex mcp list`)
2. Code intelligence MCPs need indexing first: tell the AI "index this project"
3. View detailed logs: `~/.claude/mcp.log`

### How to make AI assistants use MCPs?
The most effective way is to put rule files in the project root:
```bash
cp ~/.joe/templates/AGENTS.md /your/project/
cp ~/.joe/templates/CLAUDE.md /your/project/
```

### Which code intelligence MCP to choose?
- **Large repos (>5000 files)**: `codebase-memory-mcp` (constant query latency)
- **Need semantic search**: `codegraph`
- **Need precise refactoring**: `serena` (depends on LSP)

See [`skills/code-exploration/SKILL.md`](skills/code-exploration/SKILL.md) for details.

## Project Structure

```
joe/
├── install.sh              # Main entry, command router and menu
├── scripts/
│   ├── commands/           # tools/mcp/skills/fonts action adapters
│   ├── lib/                # Distro / Node / zsh migration / dependencies and font catalog
│   ├── ui/                 # TUI components
│   ├── install_shell.sh    # Shell environment installation
│   ├── install_fonts.sh    # User font installation
│   ├── install_devtools.sh # Development tools installation
│   ├── install_mcp_servers.sh  # MCP installation
│   ├── install_skills.sh   # Skills installation
│   ├── doctor.sh           # Environment check
│   ├── update-all.sh       # Update tools
│   └── sync-configs.sh     # Config sync
├── skills/                 # Agent skill templates
├── templates/              # Project rules and zsh configuration templates
├── .config/                # Config files (Ghostty, etc.)
└── fonts/                  # FSEX302 and JetBrains Mono fonts and license
```

## Advanced Usage

### Environment Variables
```bash
JOE_INSTALL_DIR=~/my-joe    # Custom install directory (default ~/.joe)
PROXY_URL=http://proxy:7890 # Use proxy
```

### Offline Installation
```bash
# On a machine with internet
git clone --depth 1 https://github.com/IotaHydrae/joe.git
cd joe
./install.sh devtools --list  # Confirm needed components

# Package
tar czf joe.tar.gz joe/

# On offline machine
tar xzf joe.tar.gz
cd joe
./install.sh shell  # Basic features work offline
```

### Contributing
Issues and Pull Requests are welcome!

### License
MIT License

---

**Tip**: Use `--dry-run` to preview before first run.
