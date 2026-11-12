# Omarchy-style Bash preset

Choose **Bash** under Joe's first main-menu item, or run:

```bash
./install.sh shell bash
./install.sh shell bash --dry-run
./install.sh shell bash --configure-only
# Explicitly replace the login shell if desired; takes effect after logging in again:
./install.sh shell bash --set-default
```

This preset provides four features: Starship with Git status, fzf fuzzy search, zoxide directory navigation, and bash-completion. The current login shell stays selected by default; run `bash` to try it. `--configure-only` installs no software, uses no network, and never changes the login shell; it cannot be combined with `--set-default`.

The installer supports apt (Mint/Ubuntu/Debian), pacman, dnf, and zypper, preferring installed tools and system packages. When Starship is unavailable in the system repository, it downloads the latest official stable Linux x86_64/aarch64 musl binary and verifies its SHA-256 against the same release's checksum file. Verification failure stops installation before changing Bash configuration. Configuration updates require Python 3.

Files are copied to `${XDG_CONFIG_HOME:-~/.config}/joe/bash/`. A single `joe Bash preset` block is added to `~/.bashrc`, preserving personal configuration and symlinks. Changed files get `.bak.<timestamp>` backups, keeping the latest five for each file. Repeated installation with identical content creates no extra backup. Open a new Bash session to load the preset; the installer does not reload the current session.

- `Ctrl+R` searches command history, `Ctrl+T` searches files, and `Alt+C` finds a directory to enter.
- `z keyword` jumps to a frequent directory; `zi` offers interactive selection. Ordinary `cd` is preserved.
- Up/Down search history using the current input; Tab/Shift+Tab cycle completions.
- Starship shows the Git branch and status. Bash explicitly selects this preset's `starship.toml` through `STARSHIP_CONFIG`, leaving the existing `~/.config/starship.toml` file untouched. A Nerd Font is recommended for its icons.

`init.bash` runs only in interactive Bash, does not enable strict shell options, and initializes once per shell even when sourced repeatedly. It recognizes Arch and Mint fzf paths and tolerates older fzf versions without `--bash`. When existing Omarchy configuration has already defined the integration functions, it skips duplicate Starship/fzf/zoxide initialization. Missing tools are skipped.

Source: this machine's **Omarchy 4.5.0-3 (2026-11-12)**. `inputrc` and `starship.toml` are unchanged copies of `/usr/share/omarchy/default/bash/inputrc` and `/usr/share/omarchy/config/starship.toml`. `init.bash` adapts the four features from Omarchy's `shell`/`init`, adding cross-distribution paths and repeat-loading checks. It does not depend on `/usr/share/omarchy`, and excludes mise, Omarchy-specific commands, and personal SSH helpers.

To restore, remove the section from `# >>> joe Bash preset >>>` through `# <<< joe Bash preset <<<` in `~/.bashrc`, or restore its backup after checking for newer personal edits. Then remove `~/.config/joe/bash/` if desired. If `--set-default` was used, select the previous login shell again with a command such as `chsh -s "$(command -v zsh)"`.
