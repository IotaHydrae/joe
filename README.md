# Joe

一个自动化的 zsh 环境配置安装脚本，包含 Oh My Zsh、powerlevel10k 主题和常用插件。

## 功能特性

- 自动安装 zsh（支持 apt/pacman/dnf/zypper 包管理器）
- 安装和配置 Oh My Zsh
- 安装 powerlevel10k 主题并预置配置
- 安装 zsh-autosuggestions（命令自动建议）
- 安装 zsh-syntax-highlighting（语法高亮）
- 自动识别 Oh My Zsh 已内置的插件：若插件已存在于 oh-my-zsh/plugins（或 custom/plugins）目录，则跳过单独拉取，直接在 .zshrc 的 plugins=() 中启用
- 启用一组内置推荐插件（git、sudo、extract、colored-man-pages、colorize、z、history、aliases、dirhistory、web-search、command-not-found），只追加不覆盖已有 plugins=()
- 安装 fzf（命令行模糊查找器）
- 可选安装 fastfetch（系统信息展示工具）
- 安装自定义字体
- 复制 .config 目录配置（如 ghostty 终端配置）
- 复制 SSH 配置
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
10. **SSH 配置** - .ssh 目录配置

## 注意事项

- 安装脚本会自动备份现有配置文件，格式为 `.bak.时间戳`
- 默认保留最近 5 个备份文件
- 安装完成后请重启终端或重新登录以使更改生效
