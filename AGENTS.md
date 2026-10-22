# Repository Guidelines

## Project Structure & Module Organization

- `install.sh` — the only top-level shell script; routes `./install.sh <domain> <action> [options] [args...]` and provides the curl bootstrap. The interactive menu lives in `scripts/ui/menu_main.sh` and calls back into this router, so there is a single command surface.
- `scripts/commands/` — the 2.0 action layer. `tools.sh` owns the tools domain; `mcp.sh`, `skills.sh` and `status.sh` stay thin: they translate action words into the legacy installer flags and forward everything else verbatim. Never duplicate an id or skill list here. `quickstart.sh` is the guided pipeline (moved from `scripts/bootstrap.sh`) and must locate the repo root by walking up for `install.sh`, because a hard-coded depth silently falls back to cloning.
- `scripts/lib/` — shared libraries. `deps.sh` holds `COMPONENT_GROUPS`, `COMPONENT_NAMES` and `COMPONENT_DEPS` for the tools domain; `distro.sh`, `ghostty.sh`, `github.sh`, `node.sh` are symlinks to the `lib_*.sh` files at `scripts/`.
- `scripts/ui/` — `tui_common.sh` (colors, cursor, key reading), `tui_tools.sh` (the grouped tools TUI), `tui_mcp.sh` (the grouped MCP TUI) and `menu_main.sh` (the main menu).
- `scripts/install_shell.sh` — zsh + Oh My Zsh installer, invoked by `./install.sh shell`.
- `scripts/install_devtools.sh` — optional cross-distro devtools installer (apt/dnf/pacman/zypper), invoked by `./install.sh tools install …` or the legacy `devtools`. It owns the shared helpers, prerequisite checks and dispatch; the component implementations live in `scripts/components/`.
- `scripts/tui_module.sh` — the legacy checkbox selector still used by `install_devtools.sh` and `install_skills.sh`; the MCP installer delegates to `scripts/ui/tui_mcp.sh` instead. `TUI_IDS` and the `scripts/lib/deps.sh` component lists are two views of the same ids; the CLI suite fails if they drift or if a component lacks its `install_devtools.sh` flag.
- `scripts/components/` — one module per devtools component (`<id>.sh`) exposing `component_<id>_install()`; modules may use the installer's shared helpers but must not call each other. Adding a component means adding the module, the `--<id>` flag and both id lists — the CLI suite fails if they disagree.
- `scripts/` — all component installers and maintenance scripts (`doctor.sh`, `update-all.sh`, `sync-configs.sh` live here, not at the root); repository assets remain at the root, so distinguish script paths from repository paths.
- `tests/` — `test_new_cli.sh` (CLI suite), plus pty checks for the tools TUI, the MCP TUI and the main menu; CI runs all of them.
- `docs/` — migration, troubleshooting and design guides.
- `.config/`, `fonts/`, `.p10k.zsh` — assets copied into the user's home during installation.
- `README.md` / `README.en.md` — Chinese and English docs; keep both in sync when behavior changes.
- `install.log` — runtime log, gitignored; never commit it.
- `.ssh/config` — sample config; never commit real credentials.

## Build, Test, and Development Commands

There is no build step. Key commands:

- `bash -n install.sh scripts/*.sh scripts/*/*.sh tests/*.sh` — syntax checks.
- `bash tests/test_new_cli.sh` — the CLI suite (dependency resolution, adapter translation, tools TUI through a pty). Run it from a copy of the repo in `/tmp`, not against a live checkout, and keep installers stubbed.
- `./install.sh --dry-run` — preview what the script would do without changing anything.
- `HOME=$(mktemp -d) ./install.sh --dry-run` — verify nothing leaks outside a temporary home.
- `./install.sh --no-fonts --no-config --no-p10k --no-fastfetch` — isolate one feature during testing.
- `./install.sh tools list` / `status` / `status --short` — the 2.0 read-only surface; `tools update` takes `--dry-run`, `--quiet`, `--system` and rejects per-component ids because `update-all.sh` updates everything.
- `./install.sh devtools --help` / `--list` — help must print the `依赖`/`说明` sections (rendered from the header comment, never a hard-coded line range); `--list` shows every id in `TUI_IDS` with its install status.
- `./install.sh devtools --nope` — unknown flags must exit 1 with the message on stderr.
- `./install.sh` — opens the main menu only in an interactive terminal; Enter without a choice and quitting must not install anything.

## Coding Style & Naming Conventions

- Bash only, with `set -euo pipefail` and 4-space indentation.
- Functions use `snake_case()`; flags and constants use `UPPER_SNAKE_CASE`.
- Always quote variable expansions; prefer `printf` over `echo` when writing to `.zshrc`.
- Avoid `eval` and string-concatenated shell commands (single quotes break them).
- GNU-only utilities (`find -printf`, `readlink -f`) and bash >= 4.4 are assumed (empty-array expansion under `set -u` relies on it); the script targets Linux.
- Under `set -e`, a plain `var=$(helper)` aborts the script when the helper returns non-zero. Capture with `if ! var=$(helper); then` or `var=$(helper) || true` — this matters for `resolve_deps`, which returns 1 whenever it adds a dependency, which is a normal signal rather than an error.
- `printf '%s\n' "${arr[@]}"` on an empty array still emits one blank line, and that blank becomes an empty argument downstream. Guard with `[[ ${#arr[@]} -gt 0 ]]` and skip blank tokens when reading lists.
- Command substitution strips trailing newlines, so a key read via `read -n1` inside `$()` can never see Enter. Use `dd bs=1 count=1` with `stty -icrnl -ixon` (see `scripts/tui_module.sh` and `scripts/ui/tui_common.sh`), and never run a UI that renders to stdout inside `$(...)` — hand its result back through a file.
- Log messages in `scripts/install_shell.sh` are English and prefixed with a level via `log()`; the launcher and other installers use Chinese messages.

## Testing Guidelines

`bash tests/test_new_cli.sh` is the CLI suite (also run by CI in the lint job); `tests/tui_pty_check.py`, `tests/mcp_tui_pty_check.py` and `tests/menu_pty_check.py` drive the tools TUI, the MCP TUI and the main menu through a pty. Run them from a copy of the repo in `/tmp`. The command modules accept `DEVTOOLS_SCRIPT`, `UPDATE_SCRIPT`, `MCP_SCRIPT`, `SKILLS_SCRIPT`, `TUI_SCRIPT` and `MCP_NPX_BIN` so tests can stub the installers and the Node probe — every test must use those seams, because the real installers download packages and write to the developer's home. When adding an adapter action, assert the translated argument list with a stub that echoes its parameters.

For the legacy installers, keep verifying with shell harnesses in `/tmp`:

- Simulate a fresh system with a temp `HOME` and stubbed `git`, `curl`, `sudo`, `fc-cache` in `PATH`, so clones and OMZ installation run offline.
- Run the install twice and assert idempotency: no duplicate `.zshrc` lines or `plugins=()` entries; backups are created as `.bak.<timestamp>`.
- For `scripts/install_devtools.sh`, stub `sudo`, `curl`, `npm`, `pyenv`, `pipx`, `vulkaninfo`, `fc-list` in `PATH` and point `HOME` at a temp dir; assert: an existing `~/.config/zed/settings.json` is untouched, `.zshrc` gets at most one `~/.local/bin` PATH line, no `npm install` runs when `claude`/`codex` exist, the pyenv block says `pyenv init - bash` when only `.bashrc` exists, and a failed download leaves an empty `TMPDIR` (temp files are registered with `make_tmp` and removed by the EXIT trap).
- TUI: drive `./install.sh devtools --tui` through a pty (Python `pty` module), send ↓/space/a/n/i/q, and assert exit code 0, `ESC[?25h` on exit, and that the cursor row (`ESC[7m>` or `ESC[7;2m>`) is rendered even on an already-installed row.
- Never run the real install against the developer's home directory.

## Commit & Pull Request Guidelines

- Follow Conventional Commits from the history: `fix:`, `feat:`, `docs:` with a short imperative summary and bulleted body.
- Keep one logical change per commit; leave the working tree clean.
- In PRs, describe the behavior change, link the related issue, and include dry-run/test evidence.
- Update both READMEs and the `--help` text whenever options or installed components change.

## Security & Configuration Tips

- Do not install Firefox; use Brave when a browser is needed.
- To expose Ultra in ChatGPT Desktop, enable Clash TUN and ensure the desktop app itself starts with its traffic routed through Clash. Ultra can delegate work to subagents, improving throughput on tasks that can run in parallel; check TUN and app proxy routing before changing model or CC Switch settings.
- The `curl | bash` bootstrap clones the repo to `~/.joe`; review any change to clone URLs or remote sources.
- New CLI flags must be added to the owning script's parser, the help text, and both README option tables; add new launcher commands to dispatch, the menu and both READMEs.
- Backups use `*.bak.<timestamp>` and cleanup keeps the last 5; keep the pattern stable.
