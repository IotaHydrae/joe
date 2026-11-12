# Omarchy 风格 Bash 预设

Joe 主菜单第 1 项 → **Bash**，或运行：

```bash
./install.sh shell bash
./install.sh shell bash --dry-run
./install.sh shell bash --configure-only
# 如需替换当前登录 Shell，显式选择；重新登录生效：
./install.sh shell bash --set-default
```

仅提供四项功能：Starship 提示符与 Git 状态、fzf 模糊搜索、zoxide 目录跳转、bash-completion 参数补全。默认保留当前登录 Shell，可直接运行 `bash` 体验。`--configure-only` 不安装软件、不联网、不切换默认 Shell；不能与 `--set-default` 同用。

安装器支持 apt（Mint/Ubuntu/Debian）、pacman、dnf、zypper，优先使用已安装的工具和系统软件包。系统源没有 Starship 时，下载官方最新稳定版 Linux x86_64/aarch64 musl 二进制，并用同一 Release 的 SHA-256 校验文件验证；校验失败时停止，不修改 Bash 配置。配置写入使用 Python 3。

配置复制到 `${XDG_CONFIG_HOME:-~/.config}/joe/bash/`，在 `~/.bashrc` 中添加一个带 `joe Bash preset` 标记的加载入口，保留个人配置与符号链接。更改前生成 `.bak.<时间戳>` 备份，各文件保留最近 5 份；重复执行且内容未变化时不新增备份。请用新开的 Bash 会话加载，安装器不会重载当前会话。

- `Ctrl+R` 搜索命令历史，`Ctrl+T` 搜索文件，`Alt+C` 查找并进入目录。
- `z 关键字` 跳转常用目录，`zi` 交互选择；保留普通 `cd`。
- 上下键按当前输入搜索历史；Tab/Shift+Tab 循环补全。
- Starship 显示 Git 分支和状态。Bash 会话显式设置 `STARSHIP_CONFIG` 为此预设的 `starship.toml`；现有 `~/.config/starship.toml` 文件不变。建议使用 Nerd Font 显示其中的图标。

`init.bash` 仅在交互式 Bash 加载，不开启严格模式，重复 source 也只初始化一次。兼容 Arch 和 Mint 的 fzf 脚本位置，旧版 fzf 没有 `--bash` 时仍能正常启动。已有 Omarchy 配置加载了相应函数时，跳过 Starship/fzf/zoxide 的重复初始化；工具缺失时跳过该工具。

来源为本机 **Omarchy 4.5.0-3（2026-11-12）**：`inputrc` 与 `starship.toml` 原样保存自 `/usr/share/omarchy/default/bash/inputrc` 和 `/usr/share/omarchy/config/starship.toml`；`init.bash` 根据其 `shell`/`init` 中的四项功能改写，增加跨发行版路径与重复加载检查。不依赖 `/usr/share/omarchy`，不包含 mise、Omarchy 专属命令或个人 SSH 函数。

恢复时删除 `~/.bashrc` 中 `# >>> joe Bash preset >>>` 至 `# <<< joe Bash preset <<<` 的区域，或在确认没有新增个人修改后还原对应备份；随后可删除 `~/.config/joe/bash/`。若使用过 `--set-default`，再用 `chsh -s "$(command -v zsh)"` 等命令选回原登录 Shell。
