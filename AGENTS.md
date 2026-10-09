# Repository Guidelines

## Project Structure & Module Organization

- `install.sh` — the only top-level shell script; provides the main menu, subcommand dispatch and curl bootstrap.
- `scripts/install_shell.sh` — zsh + Oh My Zsh installer, invoked by `./install.sh shell`.
- `scripts/install_devtools.sh` — optional cross-distro devtools installer (apt/dnf/pacman/zypper), invoked by `./install.sh devtools`.
- `scripts/tui_module.sh` — shared component selector; its `TUI_IDS` array is the single source of truth for devtools ids and must stay in sync with install flags and both READMEs.
- `scripts/` — all component installers, maintenance scripts and shared libraries; repository assets remain at the root, so distinguish script paths from repository paths.
- `.config/`, `fonts/`, `.p10k.zsh` — assets copied into the user's home during installation.
- `README.md` / `README.en.md` — Chinese and English docs; keep both in sync when behavior changes.
- `install.log` — runtime log, gitignored; never commit it.
- `.ssh/config` — sample config; never commit real credentials.

## Build, Test, and Development Commands

There is no build step. Key commands:

- `bash -n install.sh scripts/*.sh` — syntax checks.
- `./install.sh --dry-run` — preview what the script would do without changing anything.
- `HOME=$(mktemp -d) ./install.sh --dry-run` — verify nothing leaks outside a temporary home.
- `./install.sh --no-fonts --no-config --no-p10k --no-fastfetch` — isolate one feature during testing.
- `./install.sh devtools --help` / `--list` — help must print the `依赖`/`说明` sections (rendered from the header comment, never a hard-coded line range); `--list` shows every id in `TUI_IDS` with its install status.
- `./install.sh devtools --nope` — unknown flags must exit 1 with the message on stderr.
- `./install.sh` — opens the main menu only in an interactive terminal; Enter without a choice and quitting must not install anything.

## Coding Style & Naming Conventions

- Bash only, with `set -euo pipefail` and 4-space indentation.
- Functions use `snake_case()`; flags and constants use `UPPER_SNAKE_CASE`.
- Always quote variable expansions; prefer `printf` over `echo` when writing to `.zshrc`.
- Avoid `eval` and string-concatenated shell commands (single quotes break them).
- GNU-only utilities (`find -printf`, `readlink -f`) are assumed; the script targets Linux.
- Log messages in `scripts/install_shell.sh` are English and prefixed with a level via `log()`; the launcher and other installers use Chinese messages.

## Testing Guidelines

There is no formal test framework; verify changes with shell harnesses in `/tmp`:

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

- The `curl | bash` bootstrap clones the repo to `~/.joe`; review any change to clone URLs or remote sources.
- New CLI flags must be added to the owning script's parser, the help text, and both README option tables; add new launcher commands to dispatch, the menu and both READMEs.
- Backups use `*.bak.<timestamp>` and cleanup keeps the last 5; keep the pattern stable.
