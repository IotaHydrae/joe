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

## 注意事项

- 安装脚本会自动备份现有配置文件，格式为 `.bak.时间戳`
- 默认保留最近 5 个备份文件
- 脚本会校验 Oh My Zsh 是否真的安装成功；失败时直接退出，不会留下只有几行 `source` 的 `.zshrc`
- 如果 `.zshrc` 里只有 `source ...` 片段（缺少 `export ZSH=`、`plugins=()`、`source $ZSH/oh-my-zsh.sh`），重新执行一次 `./install.sh` 即可自动补齐
- 安装完成后请重启终端或重新登录以使更改生效
