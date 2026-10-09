---
name: joe-env
description: 了解 joe 开发环境的内容与用法。当需要安装/更新开发工具、配置 MCP 服务器、安装代理技能，或询问"这台机器装了什么/怎么装新工具"时使用。Triggers on: install devtools, add MCP server, install skill, what's installed, joe repo, 安装开发工具, 配置 MCP, 安装技能.
---

# joe 开发环境

本机由 [`joe`](https://github.com/IotaHydrae/joe) 仓库统一配置，所有安装脚本都是**幂等**的，可反复执行。

## 统一入口与组件安装器

顶层 `./install.sh` 打开编号主菜单，其他脚本全部位于 `scripts/`。按需选择操作，完成或失败后返回菜单；回车不执行操作，`q` 退出。非交互调用须指定子命令。

| 脚本 | 用途 | TUI |
|---|---|---|
| `./install.sh devtools` | 开发工具套件（9 项） | `--tui`，无安装参数默认进 TUI |
| `./install.sh mcp` | MCP 服务器（7 个） | 同上 |
| `./install.sh skills` | 代理技能 | 技能组 → 分类 → 勾选；`--category` 可直达分类 |

```bash
./install.sh devtools --list          # 查看组件及安装状态
./install.sh devtools --tui           # 勾选安装
./install.sh mcp --list
./install.sh skills --tui
./install.sh skills --categories
./install.sh skills --category kernel-dev --tui  # 按分类勾选
```

所有项目默认不勾选；非交互调用须指定安装项，只有显式 `--all` 才安装全部。

TUI 按键：`↑/↓` 移动，`PgUp/PgDn` 翻页，`Home/End` 到首尾，`空格` 勾选，`a` 全选，`n` 全不选，`i` 仅未装，`回车` 开始，`q` 退出。已安装项显示 `[✓装]` 并自动跳过。

技能菜单先列出「原有/本地技能」和「low-level-dev-skills」；后者将 142 个子技能按 25 个分类分成子菜单。编号进入，`b`/`q` 返回上一级；安装完成或退出勾选列表后返回当前菜单。重复 `--category` 可直接组合分类；原有及自定义技能归入 `local`。仅复制选择的技能，不会自动安装相关技能或系统工具。

## 已安装的工具

- **Node**: nvm + Node LTS（`~/.nvm`）
- **Python**: pyenv + 编译依赖（`~/.pyenv`），Python 版本与 pipx 按需自行安装
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
