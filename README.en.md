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
- **AI CLI**: Claude Code, Codex
- **Editors**: Zed, VS Code
- **Terminal**: Ghostty
- **Others**: MiMo Code, ChatGPT, CC Switch

```bash
./install.sh devtools              # TUI interactive selection
./install.sh devtools --list       # List all components
./install.sh devtools --node       # Install Node.js only
./install.sh devtools --python     # Install pyenv only
./install.sh devtools --ai         # Install AI CLI only
```

### 3. MCP Servers
Install Model Context Protocol servers for AI coding assistants:

- **filesystem** / **git**: File and code management
- **memory**: Conversation memory
- **context7**: Real-time documentation lookup
- **Code Intelligence**: codebase-memory-mcp, codegraph, serena (choose one)

```bash
./install.sh mcp                   # TUI interactive selection
./install.sh mcp --list            # List all MCPs
./install.sh mcp filesystem git    # Install specified ones
```

**Tip**: When first using code intelligence MCPs, tell the AI to "index this project".

### 4. Agent Skills
Add professional skill templates for AI assistants:

- **Code Exploration**: Cross-project code navigation
- **Code Quality**: Code review standards
- **Repository Exploration**: Quickly understand new projects
- **Testing**: Testing strategies and implementation
- **Embedded**: Boot optimization and specialized skills

```bash
./install.sh skills                # Install all skills
./install.sh skills gdb            # Install GDB skill only
```

## Common Commands

```bash
# Install everything (recommended for new machines)
./install.sh shell devtools mcp skills

# Environment check
./doctor.sh                        # Check installation status
./doctor.sh --quiet                # Show problems only

# Update
./update-all.sh                    # Update all components

# Config sync
./sync-configs.sh                  # Sync configuration files
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
--ai                   # Install AI CLI only
--zed                  # Install Zed editor only
--vscode               # Install VS Code only
```

### MCP Options
```bash
--tui                  # Force TUI selection interface
--list                 # List all MCP servers
filesystem git         # Install specified MCPs (supports multiple)
```

## System Support

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
├── install.sh              # Main entry, unified menu
├── doctor.sh               # Environment check
├── update-all.sh           # Update tools
├── sync-configs.sh         # Config sync
├── scripts/
│   ├── install_shell.sh    # Shell environment installation
│   ├── install_devtools.sh # Development tools installation
│   ├── install_mcp_servers.sh  # MCP installation
│   └── install_skills.sh   # Skills installation
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
