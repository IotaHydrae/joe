#!/usr/bin/env bash
# Migrate zsh configuration without sourcing the old file or running installers.

JOE_ZSH_TEMPLATE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/templates/zshrc.zsh"

configure_zshrc() {
    if ! command -v python3 >/dev/null 2>&1; then
        printf 'ERROR: python3 is required to configure zsh safely.\n' >&2
        return 1
    fi
    python3 - "$JOE_ZSH_TEMPLATE" "$HOME/.zshrc" "${DRY_RUN:-false}" \
        "${NO_P10K:-false}" "${NO_DEFAULT_PLUGINS:-false}" <<'PY'
from pathlib import Path
import datetime
import os
import re
import shlex
import shutil
import stat
import subprocess
import sys
import tempfile

template_path, requested_path, dry_run, no_p10k, no_defaults = sys.argv[1:]
requested = Path(requested_path)
home = str(requested.parent)
start_marker = '# >>> joe user configuration >>>'
end_marker = '# <<< joe user configuration <<<'
default_plugins = ['git', 'sudo', 'extract', 'z', 'history', 'dirhistory']
old_defaults = ['git', 'sudo', 'extract', 'colored-man-pages', 'colorize', 'z',
                'history', 'aliases', 'dirhistory', 'web-search',
                'command-not-found', 'you-should-use']
manual_plugins = {'zsh-autosuggestions', 'zsh-syntax-highlighting', 'nvm', 'pyenv'}

def fail(message):
    raise ValueError(message)

def extract_plugin_list(text, managed=False):
    """Read static assignments only; no old shell code is ever evaluated."""
    assignments = []
    spans = []
    pattern = re.compile(r'(?m)^[ \t]*plugins\s*(\+?=)\s*')
    for match in pattern.finditer(text):
        position = match.end()
        if managed and text[position:].startswith('("${_joe_plugins[@]}")'):
            continue
        if match.group(1) != '=' or position >= len(text) or text[position] != '(':
            fail('Dynamic plugins configuration is unsupported; original .zshrc was left unchanged.')
        quote = None
        escaped = False
        comment = False
        end = None
        for cursor in range(position + 1, len(text)):
            char = text[cursor]
            if comment:
                if char == '\n':
                    comment = False
                continue
            if escaped:
                escaped = False
                continue
            if char == '\\' and quote != "'":
                escaped = True
                continue
            if quote:
                if char == quote:
                    quote = None
                continue
            if char in "'\"":
                quote = char
            elif char == '#':
                comment = True
            elif char == '(':
                fail('Nested plugins expressions are unsupported; original .zshrc was left unchanged.')
            elif char == ')':
                end = cursor
                break
        if end is None:
            fail('Unclosed plugins list; original .zshrc was left unchanged.')
        newline = text.find('\n', end)
        line_end = len(text) if newline == -1 else newline
        if not re.fullmatch(r'[ \t]*(?:#[^\n]*)?', text[end + 1:line_end]):
            fail('Commands after plugins assignment are unsupported; original .zshrc was left unchanged.')
        try:
            plugins = shlex.split(text[position + 1:end], comments=True)
        except ValueError:
            fail('Invalid plugins list; original .zshrc was left unchanged.')
        if any(not re.fullmatch(r'[A-Za-z0-9_.+-]+', plugin) for plugin in plugins):
            fail('Dynamic plugins configuration is unsupported; original .zshrc was left unchanged.')
        assignments.append(plugins)
        spans.append((match.start(), line_end + (newline != -1)))
    return (assignments[-1] if assignments else None), spans

def normalized_path(value):
    for variable, replacement in (('${HOME}', home), ('$HOME', home),
                                   ('${NVM_DIR}', home + '/.nvm'), ('$NVM_DIR', home + '/.nvm'),
                                   ('${PYENV_ROOT}', home + '/.pyenv'), ('$PYENV_ROOT', home + '/.pyenv')):
        value = value.replace(variable, replacement)
    if value.startswith('~/'):
        value = home + value[1:]
    return value

def sole_managed_path(line):
    match = re.match(r'^(?:(?:\[\[?.*?\]\]?)[ \t]*(?:&&|\|\|)[ \t]*)?(?:export\s+)?PATH\s*=\s*(.+)$', line)
    if not match:
        return False
    try:
        values = shlex.split(match.group(1), comments=True)
    except ValueError:
        return False
    if len(values) != 1:
        return False
    managed = {home + suffix for suffix in ('/.local/bin', '/.nvm/current/bin',
                '/.pyenv/bin', '/.pyenv/shims', '/.mimocode/bin', '/.grok/bin',
                '/.cargo/bin', '/.fzf/bin')}
    parts = [normalized_path(part) for part in values[0].split(':')]
    return len(parts) > 1 and all(part in managed or part in ('$PATH', '${PATH}') for part in parts)

def managed_line(line):
    value = line.strip()
    if not value:
        return False
    if value in ('# >>> joe Node runtime >>>', '# <<< joe Node runtime <<<'):
        return True
    if re.match(r'^(?:export\s+)?ZSH_THEME\s*=', value):
        return True
    match = re.match(r'^(?:export\s+)?(ZSH|NVM_DIR|PYENV_ROOT)\s*=\s*(.*)$', value)
    if match:
        try:
            tokens = shlex.split(match.group(2), comments=True)
        except ValueError:
            return False
        suffix = {'ZSH': '/.oh-my-zsh', 'NVM_DIR': '/.nvm', 'PYENV_ROOT': '/.pyenv'}[match.group(1)]
        return len(tokens) == 1 and normalized_path(tokens[0]) == home + suffix
    if sole_managed_path(value):
        return True
    if re.match(r'^eval\s+[\'\"]?\$\((?:command\s+)?pyenv\s+(?:init|virtualenv-init)\b', value):
        return True
    # Match an optional file-test guard followed by one source statement.
    source = re.match(r'^(?:(?:\[\[?.*?\]\]?)[ \t]*(?:&&|\|\|)[ \t]*)?(?:source|\\?\.)\s+(.+)$', value)
    if source:
        try:
            tokens = shlex.split(source.group(1), comments=True)
        except ValueError:
            return False
        if not tokens:
            return False
        path = normalized_path(tokens[0])
        if len(tokens) != 1 and not (len(tokens) == 2 and tokens[1] == '--no-use' and path.endswith('/.nvm/nvm.sh')):
            return False
        return any(path.endswith(suffix) for suffix in (
            '/oh-my-zsh.sh', '/powerlevel10k.zsh-theme', '/.p10k.zsh', '/.fzf.zsh',
            '/zsh-autosuggestions.zsh', '/zsh-syntax-highlighting.zsh',
            '/.fzf/shell/completion.zsh', '/.fzf/shell/key-bindings.zsh',
            '/.nvm/nvm.sh', '/.nvm/bash_completion', '/.local/bin/env',
        )) or 'p10k-instant-prompt-' in path
    return False

def migrate_user_commands(text, spans):
    for begin, end in reversed(spans):
        text = text[:begin] + text[end:]
    boilerplate = set()
    upstream = requested.parent / '.oh-my-zsh/templates/zshrc.zsh-template'
    if upstream.is_file():
        boilerplate = {line.strip() for line in upstream.read_text().splitlines()
                       if line.lstrip().startswith('#')}
    lines = text.splitlines()
    kept = []
    stack = []
    for line in lines:
        stripped = line.strip()
        if stripped in boilerplate:
            continue
        if managed_line(line):
            continue
        if re.match(r'^if\b', stripped) and re.search(r'\bthen\s*(?:#.*)?$', stripped):
            stack.append(len(kept))
            kept.append(line)
            continue
        if re.fullmatch(r'fi\s*(?:#.*)?', stripped) and stack:
            opening = stack.pop()
            content = kept[opening + 1:]
            if not any(item.strip() and not item.lstrip().startswith('#') and
                       item.strip() not in ('else', 'then') for item in content):
                del kept[opening:]
            else:
                kept.append(line)
            continue
        # Empty lines left after stripping known init snippets are collapsed below.
        kept.append(line)
    result = '\n'.join(kept).strip('\n')
    return re.sub(r'\n{3,}', '\n\n', result)

try:
    template = Path(template_path).read_text()
    if template.count(start_marker) != 1 or template.count(end_marker) != 1:
        fail('The repository zsh template has invalid user markers.')
    target = requested.resolve()
    if target.exists() and not target.is_file():
        fail('The zsh configuration target is not a regular file; nothing was changed.')
    old = target.read_text() if target.is_file() else ''
    managed = start_marker in old or end_marker in old
    plugins, spans = extract_plugin_list(old, managed)
    if managed:
        if old.count(start_marker) != 1 or old.count(end_marker) != 1 or old.index(start_marker) > old.index(end_marker):
            fail('Invalid user markers; original .zshrc was left unchanged.')
        user = old.split(start_marker, 1)[1].split(end_marker, 1)[0].strip('\n')
        if re.search(r'(?m)^\s*plugins\s*(?:\+?=)', user):
            fail('Plugins assignments inside the user block are unsupported; original .zshrc was left unchanged.')
    else:
        user = migrate_user_commands(old, spans)
    if re.search(r'(?m)^\s*(?:export\s+)?(?:ZSH|NVM_DIR|PYENV_ROOT|ZSH_CUSTOM|ZSH_CACHE_DIR|CASE_SENSITIVE|HYPHEN_INSENSITIVE|DISABLE_COMPFIX|ZSH_COMPDUMP)\s*=', user):
        fail('Custom pre-Oh-My-Zsh settings need manual migration; original .zshrc was left unchanged.')
    if plugins is None:
        plugins = ['git'] if no_defaults == 'true' else default_plugins
    if plugins == old_defaults:
        plugins = default_plugins
    plugins = list(dict.fromkeys(plugin for plugin in plugins if plugin not in manual_plugins))
    generated = re.sub(r'(?m)^plugins=\([^\n]*\)$', 'plugins=(' + ' '.join(plugins) + ')', template, count=1)
    generated = generated.replace('JOE_ZSH_USE_P10K=1', 'JOE_ZSH_USE_P10K=' + ('0' if no_p10k == 'true' else '1'), 1)
    before, after = generated.split(start_marker, 1)
    _, after = after.split(end_marker, 1)
    generated = before + start_marker + '\n' + (user + '\n' if user else '') + end_marker + after
    zsh = shutil.which('zsh')
    if not zsh and dry_run != 'true':
        fail('zsh is required to validate configuration; original .zshrc was left unchanged.')
    if zsh:
        validation = subprocess.run([zsh, '-f', '-n'], input=generated, text=True, capture_output=True)
        if validation.returncode:
            fail('Generated zsh configuration failed syntax validation; original .zshrc was left unchanged.')
    if generated == old:
        print('Zsh configuration is already up to date.')
    elif dry_run == 'true':
        print('Dry run: would update ~/.zshrc and preserve personal commands with a timestamped backup.')
    else:
        mode = stat.S_IMODE(target.stat().st_mode) if target.exists() else 0o644
        fd, temporary = tempfile.mkstemp(prefix='.' + target.name + '.', dir=target.parent)
        try:
            with os.fdopen(fd, 'w') as handle:
                handle.write(generated)
                handle.flush()
                os.fsync(handle.fileno())
            os.chmod(temporary, mode)
            if target.exists():
                stamp = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
                index = 0
                while True:
                    backup = Path(str(requested) + '.bak.' + stamp + ('.' + str(index) if index else ''))
                    try:
                        with backup.open('xb') as dest, target.open('rb') as source:
                            shutil.copyfileobj(source, dest)
                        shutil.copystat(target, backup)
                        break
                    except FileExistsError:
                        index += 1
                print('Backed up zsh configuration to ' + str(backup))
            os.replace(temporary, target)
            backup_pattern = re.compile(re.escape(requested.name) + r'\.bak\.(\d{14})(?:\.(\d+))?$')
            backups = []
            for path in requested.parent.iterdir():
                match = backup_pattern.fullmatch(path.name)
                if match and path.is_file() and not path.is_symlink():
                    backups.append((match.group(1), int(match.group(2) or 0), path))
            for _, _, path in sorted(backups, reverse=True)[5:]:
                path.unlink()
            print('Updated zsh configuration; personal commands were preserved.')
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
except (OSError, RuntimeError, ValueError) as error:
    print('ERROR: ' + str(error), file=sys.stderr)
    sys.exit(1)
PY
}
