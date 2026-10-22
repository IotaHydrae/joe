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

```bash
./install.sh shell              # Full installation
./install.sh shell --dry-run    # Preview operations
./install.sh shell --no-fonts   # Skip fonts
```

### 2. Development Tools (Devtools)
Cross-distro development tools installation (supports apt/pacman/dnf/zypper):

- **Node.js**: nvm + LTS version
- **Python**: pyenv (doesn't pre-install Python, you choose the version)
- **AI CLI**: Claude Code, Codex (`--ai` installs only these two), Gemini CLI, OpenCode, GitHub Copilot CLI, Grok Build
- **Editors**: Zed, VS Code
- **Terminal**: Ghostty
- **Others**: MiMo Code, ChatGPT, CC Switch

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
./install.sh tools list        # List tools and status
./install.sh mcp list          # List MCP servers
./install.sh status            # One-screen summary of tools / MCP / skills
./install.sh status --short    # Single line, for scripts
./install.sh doctor            # Environment check
./install.sh --help            # Help
```

## Troubleshooting

- [Troubleshooting guide](docs/TROUBLESHOOTING.md) - common problems and fixes
- [Ghostty terminal fix](docs/GHOSTTY_FIX.md) - broken key handling in Ghostty
- [Migration guide](docs/MIGRATION.md) - 1.x to 2.0

Quick Ghostty fix:
```bash
bash scripts/fix_ghostty_term.sh  # Fixes the TERM=dumb problem
```

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
--no-fonts             # Skip font installation
--no-config            # Skip .config copy
--no-p10k              # Skip powerlevel10k
--no-fastfetch         # Skip fastfetch
--clean-backups        # Clean old backups (keep last 5)
-u, --update           # Update installed components
```

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
```

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
│   ├── commands/           # tools/mcp/skills action adapters
│   ├── lib/                # Distro / GitHub / Node / dependency libraries
│   ├── ui/                 # TUI components
│   ├── install_shell.sh    # Shell environment installation
│   ├── install_devtools.sh # Development tools installation
│   ├── install_mcp_servers.sh  # MCP installation
│   ├── install_skills.sh   # Skills installation
│   ├── doctor.sh           # Environment check
│   ├── update-all.sh       # Update tools
│   └── sync-configs.sh     # Config sync
├── skills/                 # Agent skill templates
├── templates/              # Project rule file templates
├── .config/                # Config files (Ghostty, etc.)
└── fonts/                  # Font files
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
