---
name: joe-env
description: 了解 joe 开发环境的内容与用法。当需要安装/更新开发工具、配置 MCP 服务器、安装代理技能，或询问"这台机器装了什么/怎么装新工具"时使用。Triggers on: install devtools, add MCP server, install skill, what's installed, joe repo, 安装开发工具, 配置 MCP, 安装技能.
---

# joe 开发环境

本机由 [`joe`](https://github.com/IotaHydrae/joe) 仓库统一配置，所有安装脚本都是**幂等**的，可反复执行。

## 三个安装脚本（均支持 TUI）

| 脚本 | 用途 | TUI |
|---|---|---|
| `install_devtools.sh` | 开发工具套件（9 项） | `--tui`，无参数默认进 TUI |
| `install_mcp_servers.sh` | MCP 服务器（7 个） | 同上 |
| `install_skills.sh` | 代理技能 | 同上 |

```bash
./install_devtools.sh --list          # 查看组件及安装状态
./install_devtools.sh --tui           # 勾选安装
./install_mcp_servers.sh --list
./install_skills.sh --tui
```

TUI 按键：`↑/↓` 移动，`空格` 勾选，`a` 全选，`n` 全不选，`i` 仅未装，`回车` 开始，`q` 退出。已安装项显示 `[✓装]` 并自动跳过。

## 已安装的工具

- **Node**: nvm + Node LTS（`~/.nvm`）
- **Python**: pyenv + Python 3.12 + pipx（`~/.pyenv`）
- **AI CLI**: `claude`（Claude Code）、`codex`（Codex CLI）、`mimo`（MiMo Code，官方路径 `~/.mimocode/bin`）
- **编辑器**: Zed（`~/.local/bin/zed`）、VS Code（`/usr/bin/code`）
- **终端**: Ghostty（`Ctrl+Alt+T` 打开）
- **桌面**: ChatGPT 桌面版、CC Switch

> 优先使用**官方安装路径**（官方维护、可自助升级，如 `uv self update`、`mimo upgrade`）。
> 包管理器探测与包名映射已支持 apt / dnf / pacman / zypper。

## 已配置的 MCP 服务器

`filesystem`、`git`、`memory`、`codebase-memory-mcp`、`context7`、`codegraph`、`serena`
（由 `install_mcp_servers.sh` 统一写入 Claude Code / Codex / MiMo Code）

## 约定

- 需要外网时用代理：`PROXY_URL=http://<host>:7890`（脚本支持该环境变量）
- `curl ... | bash` 类安装器都会**先校验是否为合法脚本**（拒绝 HTML 错误页）再执行
- 新增工具：在对应脚本中加 `install_<name>()`，注册到 `TUI_IDS` 与 `--list`
