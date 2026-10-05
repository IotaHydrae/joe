# Joe

> **中文** | [English](README.en.md)

一个自动化的 zsh 环境配置安装脚本，包含 Oh My Zsh、powerlevel10k 主题和常用插件。

## 快速安装

```bash
curl -fsSL https://raw.githubusercontent.com/IotaHydrae/joe/main/install.sh | bash
```

> 提示：一行式安装会先把仓库克隆到 `~/.joe`，再从仓库内继续执行，因此 `.config`、`fonts`、`.p10k.zsh` 等资源同样会被安装；`~/.joe` 已存在时直接复用（可用 `JOE_INSTALL_DIR` 环境变量改目录）。

## 功能特性

- 自动安装 zsh（支持 apt/pacman/dnf/zypper 包管理器）
- 安装和配置 Oh My Zsh
- 通过 git 克隆安装 Oh My Zsh（不走 `curl | sh`，避免下载失败被当成安装成功），克隆失败时明确报错并中止
- 保证 `.zshrc` 会加载 Oh My Zsh：文件缺失时用官方模板生成，已存在但缺少 `oh-my-zsh.sh` 时自动在顶部补上引导块（先备份原文件）
- 安装 powerlevel10k 主题并预置配置
- 安装 zsh-autosuggestions（命令自动建议）
- 安装 zsh-syntax-highlighting（语法高亮）
- 自动识别 Oh My Zsh 已内置的插件：若插件已存在于 oh-my-zsh/plugins（或 custom/plugins）目录，则跳过单独拉取，直接在 .zshrc 的 plugins=() 中启用
- 启用一组内置推荐插件（git、sudo、extract、colored-man-pages、colorize、z、history、aliases、dirhistory、web-search、command-not-found、you-should-use），只追加不覆盖已有 plugins=()
- 安装 fzf（命令行模糊查找器）
- 可选安装 fastfetch（系统信息展示工具）
- 安装自定义字体
- 复制 .config 目录配置（如 ghostty 终端配置）
- 修复 Ghostty AppImage 无法输入中文的问题：在 AppImage 旁生成 `<AppImage>.env` 并设置 `GTK_PATH`，让 AppImage 自带的 GTK 加载系统的 GTK4 输入法模块（ibus/fcitx5）
- 自动备份现有配置文件
- 支持组件更新模式
- 支持清理旧备份文件

## 安装使用

### 基础安装

```bash
./install.sh
```

### 命令行选项

| 选项 | 说明 |
|------|------|
| `-h, --help` | 显示帮助信息 |
| `-n, --dry-run` | 模拟安装，不实际修改文件 |
| `--no-fonts` | 跳过字体安装 |
| `--no-config` | 跳过 .config 目录复制 |
| `--no-p10k` | 跳过 powerlevel10k 配置 |
| `--no-fastfetch` | 跳过 fastfetch 安装 |
| `--no-default-plugins` | 跳过默认插件配置 |
| `--no-ghostty-ime` | 跳过 Ghostty AppImage 输入法修复 |
| `--clean-backups` | 清理旧备份文件（保留最近 5 个） |
| `-u, --update` | 更新已安装的组件 |

### 使用示例

```bash
# 模拟安装查看会做什么
./install.sh --dry-run

# 安装但不安装字体
./install.sh --no-fonts

# 更新已安装的组件
./install.sh --update

# 清理旧备份
./install.sh --clean-backups
```


## 开发工具套件（devtools）

仓库附带 `install_devtools.sh`，用于一键安装一组常用开发工具（独立于主 install.sh，可选执行）。这些工具记录自 Fedora 44 服务器（192.168.50.179）的实际安装需求，供新机器复现。

> **跨发行版支持**：脚本自动探测包管理器，支持 **apt**（Debian/Ubuntu）、**dnf**（Fedora/RHEL）、**pacman**（Arch）、**zypper**（openSUSE）。系统包名按发行版自动映射（如 JetBrains Mono 在 apt 下为 `fonts-jetbrains-mono`、pacman 下为 `ttf-jetbrains-mono`、dnf 下为 `jetbrains-mono-fonts`）。

### 安装内容

| 组件 | 说明 | 安装方式 |
|---|---|---|
| **nvm + Node LTS** | Node 版本管理器 + 默认 LTS 版 | 官方脚本，自动配置 zsh |
| **pyenv + Python** | Python 版本管理器 + 默认 3.12.10 | 官方脚本 + 编译依赖，自动配置 zsh |
| **pipx** | Python CLI 应用安装工具 | pip 安装 |
| **Claude Code** | Anthropic AI CLI（`claude`） | npm 全局安装 |
| **Codex CLI** | OpenAI AI CLI（`codex`） | npm 全局安装 |
| **Zed 编辑器** | 高性能代码编辑器 | 官方安装脚本 + Vulkan 驱动 |
| **JetBrains Mono 字体** | 代码字体（Zed 默认使用） | 系统包（包名按发行版映射） |
| **Ghostty 终端** | 现代终端模拟器 | dnf: COPR / apt: 社区deb / pacman: 官方包 |
| **Ctrl+Alt+T 快捷键** | Ghostty 快速打开 | labwc rc.xml + xdg-terminal-exec |
| **VS Code 编辑器** | 微软代码编辑器 | 微软官方仓库（dnf/apt/zypper）/ pacman: `code` |

### 用法

```bash
./install_devtools.sh             # 安装全部工具
./install_devtools.sh --node      # 只装 Node 工具链 (nvm + LTS)
./install_devtools.sh --python    # 只装 Python 工具链 (pyenv + pipx)
./install_devtools.sh --ai        # 只装 AI CLI (claude-code + codex)
./install_devtools.sh --zed       # 只装 Zed 编辑器 + JetBrains Mono
./install_devtools.sh --ghostty   # 只装 Ghostty 终端 + Ctrl+Alt+T 快捷键
./install_devtools.sh --vscode    # 只装 VS Code 编辑器
./install_devtools.sh --list      # 查看用法
```

### 环境变量

- `NODE_LTS` - 指定 Node 版本（默认最新 LTS）
- `PYTHON_VERSION` - 指定 Python 版本（默认 3.12.10）
- `PROXY_URL` - 代理地址，如 `http://192.168.50.182:7890`（外网下载慢时使用）

### 注意事项

- 所有组件**幂等**：已安装的会自动跳过，可安全重复执行
- AI CLI（Claude Code/Codex）安装后需各自登录/配置 API key 才能使用
- Zed 依赖 Vulkan，脚本按发行版自动安装对应驱动（pacman 下为 `vulkan-radeon`+`vulkan-intel`）
- Ghostty 在 Budgie/labwc 桌面下依赖 `xdg-terminal-exec`（AUR/zypper 无此包时会提示跳过）
- 安装完成后新开终端生效（或 `source ~/.zshrc`）


## 安装内容

### 依赖要求

- git、curl（非 root 用户还需要 sudo）
- fc-cache（可选，缺失时自动跳过字体缓存更新）

### 安装的组件

1. **zsh** - 如未安装会自动通过系统包管理器安装
2. **Oh My Zsh** - zsh 配置框架
3. **powerlevel10k** - 快速且可定制的 zsh 主题
4. **fzf** - 命令行模糊查找器
5. **zsh-autosuggestions** - 根据历史记录提供命令建议
6. **zsh-syntax-highlighting** - 命令语法高亮
7. **fastfetch** - 系统信息展示工具（可选）
8. **自定义字体** - Fixedsys 等字体（可选）
9. **配置文件** - .config 目录下的配置（如 ghostty 终端）
10. **Ghostty AppImage 输入法修复** - 在 `~/.local/bin`（或 `~/Applications`）找到 Ghostty AppImage 时，为其写入 `<AppImage>.env` 把 `GTK_PATH` 指向系统 GTK4 输入法模块的软链接目录（可用 `GHOSTTY_APPIMAGE` 指定路径，用 `--no-ghostty-ime` 跳过）

## 注意事项

- 安装脚本会自动备份现有配置文件，格式为 `.bak.时间戳`
- 默认保留最近 5 个备份文件
- 脚本会校验 Oh My Zsh 是否真的安装成功；失败时直接退出，不会留下只有几行 `source` 的 `.zshrc`
- 如果 `.zshrc` 里只有 `source ...` 片段（缺少 `export ZSH=`、`plugins=()`、`source $ZSH/oh-my-zsh.sh`），重新执行一次 `./install.sh` 即可自动补齐
- Ghostty AppImage 的输入法修复与文件名绑定（AppImage 运行时会读取同名的 `.env`）；换成新版本、文件名变化后，重新执行一次 `./install.sh` 即可重新指向，且需要完全退出已打开的 Ghostty 窗口再启动才会生效
- 安装完成后请重启终端或重新登录以使更改生效
