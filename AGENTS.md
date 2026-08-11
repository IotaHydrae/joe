# Repository Guidelines

## Project Structure & Module Organization

- `install.sh` — the only source file, a self-contained bash installer for zsh + Oh My Zsh.
- `.config/`, `fonts/`, `.p10k.zsh` — assets copied into the user's home during installation.
- `README.md` / `README.en.md` — Chinese and English docs; keep both in sync when behavior changes.
- `install.log` — runtime log, gitignored; never commit it.
- `.ssh/config` — sample config; never commit real credentials.

## Build, Test, and Development Commands

There is no build step. Key commands:

- `bash -n install.sh` — syntax check.
- `./install.sh --dry-run` — preview what the script would do without changing anything.
- `HOME=$(mktemp -d) ./install.sh --dry-run` — verify nothing leaks outside a temporary home.
- `./install.sh --no-fonts --no-config --no-p10k --no-fastfetch` — isolate one feature during testing.

## Coding Style & Naming Conventions

- Bash only, with `set -euo pipefail` and 4-space indentation.
- Functions use `snake_case()`; flags and constants use `UPPER_SNAKE_CASE`.
- Always quote variable expansions; prefer `printf` over `echo` when writing to `.zshrc`.
- Avoid `eval` and string-concatenated shell commands (single quotes break them).
- GNU-only utilities (`find -printf`, `readlink -f`) are assumed; the script targets Linux.
- Log messages are English and prefixed with a level via `log()`.

## Testing Guidelines

There is no formal test framework; verify changes with shell harnesses in `/tmp`:

- Simulate a fresh system with a temp `HOME` and stubbed `git`, `curl`, `sudo`, `fc-cache` in `PATH`, so clones and OMZ installation run offline.
- Run the install twice and assert idempotency: no duplicate `.zshrc` lines or `plugins=()` entries; backups are created as `.bak.<timestamp>`.
- Never run the real install against the developer's home directory.

## Commit & Pull Request Guidelines

- Follow Conventional Commits from the history: `fix:`, `feat:`, `docs:` with a short imperative summary and bulleted body.
- Keep one logical change per commit; leave the working tree clean.
- In PRs, describe the behavior change, link the related issue, and include dry-run/test evidence.
- Update both READMEs and the `--help` text whenever options or installed components change.

## Security & Configuration Tips

- The `curl | bash` bootstrap clones the repo to `~/.joe`; review any change to clone URLs or remote sources.
- New CLI flags must be added to `parse_args`, the help text, and both README option tables.
- Backups use `*.bak.<timestamp>` and cleanup keeps the last 5; keep the pattern stable.
