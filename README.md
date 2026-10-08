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



## MCP 怎么用？会不会自动调用？

**结论：会自己调用，但"自动"的程度差别很大。** 而且有一个关键真相：
**代理的内置工具通常会把 MCP 挤掉**——有内置 Read/Write/Bash 时，代理往往不去调 filesystem/git MCP。

### 实测：各 MCP 暴露的工具数量

| MCP | 工具数 | 自动调用程度 |
|---|---:|---|
| `codegraph` | 42 | 需先索引 |
| `serena` | 23 | 需先激活项目 |
| `codebase-memory-mcp` | 17 | 需先索引 |
| `filesystem` | 14 | 常被内置工具挤掉 |
| `git` | 12 | 常被内置工具挤掉 |
| `memory` | 9 | 半自动，建议明确说"记住…" |
| `context7` | 2 | 建议明确点名 |
| **合计** | **119** | |

### 三类触发情况

**① 基本全自动**
- `context7` — 问"XX 库最新 API"时可能用，但描述泛，代理常直接 WebFetch 绕过。**建议点名**。

**② 会被内置工具挤掉**
- `filesystem` / `git` — 代理自带的 Read/Write/Bash 更顺手，通常不会调这两个。
  真正有用的场景是内置做不到的：`search_files`（按大小/时间筛）、`directory_tree`（整棵树）、
  `list_allowed_directories`、`git_diff_staged`、`git_show`。

**③ 必须先"准备"，否则是空壳** ⚠️

| MCP | 必须先做 | 之后才能 |
|---|---|---|
| `codebase-memory-mcp` | `index_repository` | `trace_path` 调用链、`search_graph` 找符号、`detect_changes` 影响面 |
| `codegraph` | `codegraph_index_directory` | `analyze_impact`、`find_circular_deps`、`find_dead_imports` |
| `serena` | `activate_project` | `find_symbol`、`rename_symbol`、`find_referencing_symbols` |

> **首次在一个项目里使用，必须主动触发一次索引**——否则图谱查询返回空。

### ⚠️ 119 个工具是负担

7 个 server 共 119 个工具，每次请求都要带上全部工具定义，占用可观的上下文。
**工具一多，代理选择时反而容易"看不见"或选错。**

如果发现代理老是不用 MCP，先考虑精简：

```bash
claude mcp list                       # 看当前有哪些
claude mcp remove -s user serena      # 暂时拿掉不常用的
```

### ✅ 最有效的办法：放进项目的规则文件

别指望代理"自己想起来"。用 `templates/` 里的规则文件，**每个会话都会加载**：

```bash
cd /your/project
cp ~/iotahydrae/joe/templates/AGENTS.md .
cp ~/iotahydrae/joe/templates/CLAUDE.md .
```

| 文件 | 谁读 |
|---|---|
| `AGENTS.md` | Codex、MiMo Code 原生读取；Claude Code 也支持 |
| `CLAUDE.md` | 内容是 `@AGENTS.md`，规则只维护一份 |

> ⚠️ **一个容易踩的坑**：Claude Code 虽然原生支持 `AGENTS.md`，
> 但**项目里存在 `CLAUDE.md` 时默认会忽略 `AGENTS.md`**。所以两者都放最稳妥——
> 或者在你已有的 `CLAUDE.md` 末尾加一行 `@AGENTS.md`（**别覆盖原文件**）。

详见 [`templates/README.md`](templates/README.md)。也可以放到全局位置（`~/.claude/CLAUDE.md` 等）对所有项目生效。

### 怎么确认真的调用了？

在 Claude Code 会话里输入 `/mcp` 看连接状态。调用发生时会看到 `mcp__` 前缀：

```
mcp__codebase-memory-mcp__trace_path(direction="inbound", ...)
```

一直没看到 `mcp__` 前缀 = 没被调用。

### 代码索引 MCP 怎么选？（实测）

三个代码智能 MCP 不是"随便挑一个"——**选型取决于①语言有没有 LSP ②仓库规模**。

#### 实测数据

在三个量级的仓库上用 JSON-RPC 实测（`mode` 取默认）：

| 仓库 | 文件 | MCP | 索引耗时 | 热查询延迟 | 单项目落盘 |
|---|---:|---|---:|---:|---:|
| joe (shell) | 46 | codebase-memory-mcp | 1.6s | **0.05s** | 452K |
| | | codegraph | 21s\* | 0.35s | — |
| | | serena | 0.1s | 0.2s | 0 |
| ripgrep (Rust) | 266 | codebase-memory-mcp | 2.4s | **0.05s** | 2.5M |
| | | codegraph | 0.8s | 0.45s | — |
| | | serena | 0.1s | **❌ 报错** | 0 |
| redis (C) | 1896 | codebase-memory-mcp | 9.3s | **0.05s** | 16M |
| | | codegraph | 11.5s | 0.85s | — |
| | | serena | 0.1s | 56.4s → 0.9s | 0 |

\*首次运行，含一次性嵌入模型下载

#### 三个关键结论

**① `codebase-memory-mcp` 的查询延迟恒定。**
46 文件 → 1896 文件（40 倍），查询始终 **0.05s**——它是预建 SQLite 图，延迟不随代码量增长。
`codegraph`（0.35→0.85s）和 `serena`（0.2→0.9s）**都会随规模增长**。
→ **大仓库选 cmm，理由是延迟不膨胀。**

**② `serena` 的瓶颈是语言，不是项目大小。**
实测 redis(C) 首次 `find_symbol` 56.4s，查存储发现真凶是 **LSP 自动下载**：

```
~/.serena/language_servers/static/
  ClangdLanguageServer/   281M   ← C 语言
  BashLanguageServer/      33M
  RustAnalyzer/             0    ← 下载失败/空
```

Rust 项目直接**硬失败**（不是降级）：
```
Please install rust-analyzer via:
  - Rustup: rustup component add rust-analyzer
```
→ **serena 在语言服务器缺失时不可用**，选型前必须先确认。

**③ 三者都有一次性成本，只是位置不同。**

| MCP | 一次性成本 | 之后 |
|---|---|---|
| `codebase-memory-mcp` | 无 | 每项目 452K–16M |
| `codegraph` | **约 128M 嵌入模型**（fastembed，做语义检索） | 每项目约 12M |
| `serena` | **每语言 33–281M LSP** | 不落盘（常驻内存） |

#### 选型矩阵

| 场景 | 选 | 理由 |
|---|---|---|
| 大仓库（>5000 文件） | `codebase-memory-mcp` | 查询延迟**恒定** |
| 中仓库 + 语义搜索 | `codegraph` | fastembed 向量检索 |
| 小-中仓库 + 精确重构 | `serena` | LSP 符号级，`rename_symbol` 最准 |
| 语言冷门 / 无可用 LSP | cmm 或 codegraph | serena **直接不可用** |
| C/C++ 项目 | 注意 serena 首次要拉 281M clangd | 首次很慢 |

#### 检查语言支持

```bash
# serena 自动下载过哪些 LSP
ls ~/.serena/language_servers/static/

# 宿主已装的 LSP（serena 可复用）
command -v rust-analyzer gopls clangd pyright-langserver typescript-language-server
```

> 详细的工具级选型（哪个需求用哪个工具）见 [`skills/code-exploration/SKILL.md`](skills/code-exploration/SKILL.md)。

### 推荐起手式

```bash
cd /your/project

# 1) 首次: 建立索引 (一次就够, 大改动后重建)
> 索引这个项目

# 2) 之后正常提问, 让它自己选工具
> 这个函数被哪些地方调用了?
> 我要改这个接口, 影响面有多大?
> 有没有循环依赖?

# 3) 需要精确控制时点名
> 用 serena 把所有 get_user_* 重命名成 fetch_user_*
> 用 context7 查一下 React 19 的 use() 怎么用
```

> 我们安装的 `code-exploration` 技能也在做同样的事，但它要代理判断"相关"才加载，
> 属于第二层保险。**项目根目录的规则文件是第一层，最直接。**

---

## 跨发行版支持

脚本不绑定某一个发行版。已用容器实测的发行版：

| 发行版 | 包管理器 | 实测状态 |
|---|---|---|
| **Ubuntu 24.04 LTS** (noble) | apt | ✅ `--check` 全部正确解析 |
| **Linux Mint 22.3** | apt (基于 noble) | ✅ 与 Ubuntu 24.04 同一套映射 |
| **Arch Linux / CachyOS** | pacman | ✅ `--check` 全部正确解析 |
| **Fedora** | dnf | ✅ 本机实机验证 |
| openSUSE | zypper | 已适配（未实测） |

### 设计：按"可用性"解析包名，而非硬编码

各发行版（甚至同一发行版的不同版本）包名不同。例如 Ubuntu 24.04 的 **t64 重命名**：

| 逻辑名 | Ubuntu ≤22.04 | Ubuntu ≥24.04 | Arch | Fedora |
|---|---|---|---|---|
| `fuse2` | `libfuse2` | **`libfuse2t64`** | `fuse2` | `fuse` |
| `ncurses-dev` | `libncursesw5-dev` | **`libncurses-dev`** | (base-devel) | `ncurses-devel` |
| `ncurses-tools` | `ncurses-bin` | `ncurses-bin` | `ncurses` | `ncurses` |
| `xdg-terminal-exec` | `xdg-terminal-exec` | `xdg-terminal-exec` | `xdg-terminal-exec` | `xdg-terminal-exec` |
| `mesa-vulkan-drivers` | `mesa-vulkan-drivers` | 同左 | `vulkan-radeon` + `vulkan-intel` | `mesa-vulkan-drivers` |

`lib_distro.sh` 的做法是**声明候选**，运行时按实际情况选择：

```bash
# 组之间用空格(都要装), 组内用 | 分隔备选(选一个可用的)
fuse2)               echo "libfuse2t64|libfuse2" ;;
mesa-vulkan-drivers) echo "vulkan-radeon vulkan-intel" ;;
```

这样 Ubuntu 22.04/24.04/26.04、Mint、Pop!_OS 等衍生版都不需要单独判断版本。

### 各发行版的组件安装方式

| 组件 | apt (Ubuntu/Mint) | pacman (Arch/CachyOS) | dnf (Fedora) |
|---|---|---|---|
| **Ghostty** | 官方仓库(26.04+) / 社区 .deb / snap | 官方 `extra` | COPR scottames/ghostty |
| **VS Code** | 微软 apt 源 | 官方 `extra` (`code`) | 微软 dnf 源 |
| **ChatGPT 桌面** | 官方 .deb | 官方 `install-arch.sh` | 官方 .rpm |
| **CC Switch** | 官方 .deb | AppImage + `fuse2` | 官方 .rpm |
| **Node / Python / Zed / MiMo** | 发行版无关（nvm / pyenv / 官方脚本） | 同左 | 同左 |

> Ghostty 在 Ubuntu 24.04 尚无官方包（26.04 起才有）。脚本的社区 .deb 回退会
> **先把安装脚本下载下来校验**（拒绝 HTML 错误页），再在**临时目录**中执行——
> 因为该脚本会把约 50MB 的 .deb 下到当前目录，直接在仓库里跑会污染工作区。

### 查看本机适配情况

```bash
./install_devtools.sh --check
```

只报告不改动：

```
== 发行版 ==
  发行版:      Ubuntu 24.04.5 LTS
  ID/ID_LIKE:  ubuntu / debian
  版本/代号:   24.04 / noble
  家族:        debian
  包管理器:    apt
  Ubuntu 基线: 24.04

== 系统包解析 ==
  fuse2                  -> libfuse2t64
  ncurses-dev            -> libncurses-dev
  ...

== 各组件安装方式 ==
  ghostty      官方仓库(26.04+) / 社区 .deb / snap
  vscode       微软 apt 源 (packages.microsoft.com)
  ...
```

### 其他兼容性处理

- **`sudo` 兼容**：以 root 运行（容器/WSL）或系统没有 `sudo` 时自动降级，不再直接报错
- **Ubuntu 衍生版识别**：Mint/Zorin/Pop 等通过 `UBUNTU_CODENAME` 反查 Ubuntu 基线版本
- **镜像回退**：GitHub 下载走多镜像 + SHA256 校验（部分网络下直连会截断）

### 用容器验证

仓库的跨发行版适配是通过容器实测的：

```bash
podman run --rm -v "$PWD:/joe:ro,z" docker.io/library/ubuntu:24.04 \
    /bin/bash -c "apt-get update -qq && cd /joe && ./install_devtools.sh --check"

podman run --rm -v "$PWD:/joe:ro,z" docker.io/library/archlinux \
    /bin/bash -c "pacman -Sy --noconfirm && cd /joe && ./install_devtools.sh --check"
```

> Fedora 上挂载需要 `:z` 做 SELinux 重标，否则容器读不到文件。

---

## 安装器选择规则

`install_devtools.sh`、`install_mcp_servers.sh`、`install_skills.sh` 无参数时进入 TUI，**所有项目默认不勾选**。用空格按需选择，再按回车安装；直接回车或退出不会安装任何项目。非交互终端必须显式指定组件、服务器、技能或 `--all`，否则报错退出。

| 选项 | 三个组件安装器的行为 |
|---|---|
| `--tui` | 打开交互选择界面，默认不勾选 |
| `--all` | 显式安装全部项目，不能与 `--tui` 同用 |
| `--list` | 列出项目和当前状态 |
| `-h, --help` | 查看用法和依赖 |

## 全流程脚本

围绕"新机器 → 部署 → 体检 → 升级 → 备份"的完整闭环：

| 脚本 | 作用 |
|---|---|
| `bootstrap.sh` | 新机器一键部署（克隆 + 三个安装器 + 体检） |
| `doctor.sh` | 环境体检：工具 / MCP / 技能是否就绪，给出修复建议 |
| `repair_ghostty.sh` | 修复已有 Ghostty 的 terminfo 与桌面终端入口 |
| `update-all.sh` | 用各工具官方自更新机制统一升级 |
| `sync-configs.sh` | 把本机配置（脱敏后）备份进仓库 / 从仓库恢复 |

### bootstrap.sh — 新机器一键部署

```bash
./bootstrap.sh                    # 交互: 各阶段进入 TUI，默认不勾选
./bootstrap.sh --yes              # 非交互: 全部安装 (适合脚本/CI)
./bootstrap.sh --only mcp,skills  # 只跑指定阶段
./bootstrap.sh --skip devtools    # 跳过指定阶段
./bootstrap.sh --dir ~/joe        # 指定克隆目录
```

也可直接管道运行（此时会先克隆自己）：

```bash
curl -fsSL <raw-url>/bootstrap.sh | bash
```

阶段：`devtools` | `mcp` | `skills` | `doctor`（默认全部）。
环境变量：`JOE_DIR`、`JOE_REPO`、`PROXY_URL`。

### doctor.sh — 环境体检

```bash
./doctor.sh              # 常规检查 (较快)
./doctor.sh --mcp        # 额外实际连接每个 MCP (慢, 每个约 10-30s)
./doctor.sh --quiet      # 只输出问题项
./doctor.sh --json       # 机器可读输出
```

检查项：系统信息、基础工具、Node/Python 工具链、AI CLI、编辑器/终端/桌面、
7 个 MCP 在三端的配置、7 个技能在 5 个代理目录的就位情况、技能 frontmatter 合法性。

退出码 `0` = 无失败项。失败项会附带**具体的修复命令**。

### update-all.sh — 统一升级

```bash
./update-all.sh             # 更新工具链 + AI CLI + MCP 引擎 + 仓库自身
./update-all.sh --system    # 额外升级系统包 (dnf/apt/pacman/zypper)
./update-all.sh --dry-run   # 只显示会执行什么
```

优先走**官方自更新**（这正是选择官方安装路径的原因）：

| 组件 | 更新方式 |
|---|---|
| nvm / pyenv | `git pull` / `pyenv update` |
| uv | `uv self update` |
| pipx | `pip install --user -U pipx` |
| Claude Code | `claude update` |
| Codex CLI | `npm update -g @openai/codex` |
| MiMo Code | `mimo upgrade` |
| codebase-memory-mcp | `codebase-memory-mcp update -y` |
| CodeGraph 引擎 | 镜像补拉 + SHA256 校验 |

单项有 300s 超时保护（`UPDATE_TIMEOUT` 可调），失败不影响其余项。更新器只更新已安装工具，不再自动执行 MCP / 技能安装器；需要配置 MCP 或更新技能时，运行对应安装器按需选择。`bootstrap.sh --yes` 仍表示显式选择全部安装。

### sync-configs.sh — 配置备份

```bash
./sync-configs.sh list            # 列出映射与状态
./sync-configs.sh export          # 导出(脱敏)到 configs/
./sync-configs.sh export --check  # 只统计会擦除多少敏感项
./sync-configs.sh import          # 从 configs/ 恢复 (原文件备份到 ~/.joe-config-backup/)
./sync-configs.sh diff            # 对比本机与仓库备份
```

安全设计：

- **白名单**：只处理明确列出的文件，不做目录级全量拷贝
- **脱敏**：导出前擦除 `sk-*` / `ghp_*` / `AKIA*` / `Bearer` / 私钥 / `*token*`、`*password*` 等键值
- **隐私**：`~/.claude.json` 只提取 `mcpServers`，丢弃 `userID` / `machineID` / `projects`
- **不自动提交**：导出后请 `git diff configs/` 复核再提交

> 脱敏是尽力而为的兜底，不保证覆盖所有密钥形式，提交前请自行确认。

### 共享库与 CI

- `lib_github.sh` — GitHub 下载相关共享函数：`download_installer`（拒绝 HTML 错误页）、
  `github_mirror_download`（镜像回退）、`codegraph_fetch_engine_mirror`（带 SHA256 校验）
- `tui_module.sh` — 通用 TUI 选择器，被三个安装器复用
- `.shellcheckrc` — ShellCheck 排除项，本地与 CI 共用
- `.github/workflows/ci.yml` — push/PR 时运行：`bash -n`、ShellCheck（severity=warning）、
  可执行位检查、技能 frontmatter 校验、`references/` 链接可达性、TUI 模块完整性

---

## 代理技能（install_skills.sh）

仓库的 `skills/` 目录存放可复用的 **Agent Skills**，由 `install_skills.sh` 安装到各 AI 代理。

### 技能目录结构

```
skills/
├── README.md
└── <skill-name>/
    └── SKILL.md          # 必需, 含 YAML frontmatter 的 name/description
```

### 用法

```bash
./install_skills.sh                # 默认进入 TUI，不预选；非交互须指定技能
./install_skills.sh --all          # 显式安装全部技能
./install_skills.sh --tui          # 强制 TUI 勾选
./install_skills.sh --list         # 列出技能及安装状态
./install_skills.sh joe-env        # 只装指定技能
```

与 devtools / MCP 脚本同款 TUI：`↑↓` 移动、`空格` 勾选、`a/n/i` 快捷键、`回车` 开始、`q` 退出；已安装技能显示 `[✓装]` 自动跳过。

### 安装位置（按已安装的代理自动选择）

| 目录 | 归属 |
|---|---|
| `~/.agents/skills/` | 通用（跨工具约定，总是安装） |
| `~/.claude/skills/` | Claude Code |
| `~/.codex/skills/` | Codex CLI |
| `~/.config/mimocode/skills/` | MiMo Code（原生路径） |
| `~/.copilot/skills/` | GitHub Copilot（目录存在时） |

> MiMo Code 也会扫描 `~/.claude`、`~/.agents`、`~/.codex`、`~/.opencode` 下的 `skills/**/SKILL.md`，
> 因此安装到这些目录可同时被多个代理发现。

### 内置技能

| 技能 | 用途 |
|---|---|
| **joe-env** | 说明本机装了哪些工具/MCP、三个安装脚本怎么用 |
| **code-exploration** | 用 MCP 图谱工具探索代码（替代 grep + 逐文件读） |
| **developer-knowledge** | 从开发过程提炼高信号工程知识库（写笔记/沉淀经验/组织知识库） |
| **developer-testing** | 设计可复用、可信赖的测试体系（oracle、基准、黄金数据、观测与预期） |
| **developer-code-quality** | 面向长期可维护性的编码与审查准则（命名、控制流、抽象与重复权衡） |
| **developer-repository-exploration** | 在先理解后修改：陌生仓库侦察、构建系统、调用链、数据/状态流、生命周期 |
| **embedded-linux-boot-optimizer** | 测量驱动的嵌入式 Linux 启动优化（U-Boot、内核 initcall、DT、systemd） |

> 这些技能采用**渐进式披露**结构：`SKILL.md` 精简（frontmatter + 核心准则 + 章节索引），
> 完整原文放在 `references/full.md`，代理仅在需要细节时才读取，避免占用上下文。

### 添加自己的技能

```bash
mkdir -p skills/my-skill
cat > skills/my-skill/SKILL.md <<'EOF'
---
name: my-skill
description: 何时该用我（写清触发场景, 这是代理唯一的判断依据）
---

# 标题
技能正文...
EOF
./install_skills.sh --list     # 会自动发现
./install_skills.sh --tui      # 勾选安装
```

脚本幂等：内容变化则更新，未变化跳过。

---

## MCP 服务器安装器（install_mcp_servers.sh）

仓库附带 `install_mcp_servers.sh`，用于安装并配置各种 MCP（Model Context Protocol）服务器，自动接入已安装的 AI CLI 工具：

| 目标工具 | 配置方式 |
|---|---|
| **Claude Code** | `claude mcp add -s user`（全局作用域） |
| **Codex CLI** | `codex mcp add`（写入 ~/.codex/config.toml） |
| **MiMo Code** | 编辑 ~/.config/mimocode/mimocode.jsonc |

### 支持的 MCP 服务器

| 服务器 | 说明 | 运行方式 |
|---|---|---|
| **filesystem** | 安全文件操作（官方参考服务器） | `npx @modelcontextprotocol/server-filesystem` |
| **git** | Git 仓库读取/搜索/操作 | `uvx mcp-server-git`（PyPI 官方包） |
| **memory** | 知识图谱持久记忆 | `npx @modelcontextprotocol/server-memory` |
| **codebase-memory-mcp** | 代码库知识图谱（158 语言，子毫秒查询） | 官方静态二进制 `codebase-memory-mcp` |
| **context7** | 实时文档/代码示例检索（Upstash） | `npx @upstash/context7-mcp` |
| **codegraph** | 跨语言代码图谱（42 工具 / 38 语言） | `npm i -g @astudioplus/codegraph-mcp` + 引擎 |
| **serena** | 语义代码检索与编辑（oraios） | `uvx --from serena-agent serena start-mcp-server` |

### 用法

```bash
./install_mcp_servers.sh                 # 默认进入 TUI，不预选；非交互须指定服务器
./install_mcp_servers.sh --all           # 显式安装全部 MCP
./install_mcp_servers.sh --tui           # 强制进入 TUI 勾选界面
./install_mcp_servers.sh --list          # 列出可用 MCP 及当前配置状态
./install_mcp_servers.sh filesystem      # 只装 filesystem MCP
./install_mcp_servers.sh git memory      # 装多个 MCP
./install_mcp_servers.sh codebase-memory-mcp   # 代码知识图谱
./install_mcp_servers.sh context7 codegraph serena  # 文档检索 + 代码图谱 + 语义检索
```

### TUI 交互式选择

与 `install_devtools.sh --tui` 同款界面（共用 `tui_module.sh` 通用库）：

- **↑/↓** 移动光标，**空格** 勾选/取消
- **a** 全选，**n** 全不选，**i** 仅选未配置
- **回车** 开始安装，**q** 退出
- 所有 MCP 默认不勾选；只有在所有已安装客户端都已配置时才显示 `[✓装]` 并跳过，因此可以补齐新安装客户端的配置

### 自定义 filesystem 可访问目录

默认允许访问 `$HOME` 和 `/tmp`，可通过环境变量覆盖：

```bash
FILESYSTEM_DIRS="/home/dev /data /projects" ./install_mcp_servers.sh filesystem
```

### 扩展新 MCP 服务器

脚本结构清晰，新增服务器只需：

1. 添加一个 `install_<name>_mcp()` 函数（用 `mcp_add_all <name> <command...>` 写入三个工具）
2. 把 id 加入 `MCP_IDS_AVAILABLE`，并在 `tui_component_installed` / `tui_component_name` 中登记
3. 加入参数解析与主流程的 case 分支

脚本幂等：各客户端已配置的服务器自动跳过，可安全重复执行。Claude / MiMo 配置检测依赖 `python3`；CLI 添加失败会返回非零退出码。MiMo 配置解析失败时保留原文件，成功写入前备份为 `*.bak.<timestamp>`（保留最近 5 份），随后原子替换；JSONC 注释会转换为标准 JSON，字符串内容保持不变。

---


### 安装路径原则

脚本**优先使用官方安装路径**（官方维护，支持自助升级），官方不可用时回退备用方式：

| 工具 | 首选（官方） | 回退 | 说明 |
|---|---|---|---|
| **Claude Code** | `claude.ai/install.sh` | npm | npm 方式官方已标记 deprecated；官方脚本在部分区域被封锁时会自动回退 |
| **Codex CLI** | npm `@openai/codex` | — | 官方推荐即 npm / Homebrew / 二进制 |
| **MiMo Code** | `mimo.xiaomi.com/install` | npm | 官方脚本装到 `~/.mimocode/bin`，支持 `mimo upgrade` |
| **uv / uvx** | `astral.sh/uv/install.sh` | pip / brew | 官方独立安装器支持 `uv self update`；pip 方式会禁用自更新 |
| **codebase-memory-mcp** | 官方 `install.sh` | — | 支持 `codebase-memory-mcp update` |
| **nvm / pyenv / Zed / VS Code / Ghostty / ChatGPT** | 各自官方脚本或仓库 | — | — |

> 安全细节：所有 `curl ... | bash` 类安装器都会先下载到临时文件并**校验是否为合法脚本**（拒绝 HTML 错误页/区域限制页），再执行。

---

## 开发工具套件（devtools）

仓库附带 `install_devtools.sh`，用于一键安装一组常用开发工具（独立于主 install.sh，可选执行）。这些工具记录自 Fedora 44 服务器（192.168.50.179）的实际安装需求，供新机器复现。

> **跨发行版支持**：脚本自动探测包管理器，支持 **apt**（Debian/Ubuntu）、**dnf**（Fedora/RHEL）、**pacman**（Arch）、**zypper**（openSUSE）。系统包名按发行版自动映射（如 JetBrains Mono 在 apt 下为 `fonts-jetbrains-mono`、pacman 下为 `ttf-jetbrains-mono`、dnf 下为 `jetbrains-mono-fonts`）。

### 安装内容

| 组件 | 说明 | 安装方式 |
|---|---|---|
| **nvm + Node LTS** | Node 版本管理器 + 默认 LTS 版 | 官方脚本，自动配置 zsh |
| **pyenv** | Python 版本管理器，不自动安装 Python | 官方脚本 + 编译依赖，自动配置 bash/zsh |
| **Claude Code** | Anthropic AI CLI（`claude`） | npm 全局安装 |
| **Codex CLI** | OpenAI AI CLI（`codex`） | npm 全局安装 |
| **Zed 编辑器** | 高性能代码编辑器 | 官方安装脚本 + Vulkan 驱动 |
| **JetBrains Mono 字体** | 代码字体（Zed 默认使用） | 系统包（包名按发行版映射） |
| **Ghostty 终端** | 现代终端模拟器 | dnf: COPR / apt: 社区deb / pacman: 官方包 |
| **Ctrl+Alt+T 快捷键** | Ghostty 快速打开 | labwc rc.xml + xdg-terminal-exec |
| **VS Code 编辑器** | 微软代码编辑器 | 微软官方仓库（dnf/apt/zypper）/ pacman: `code` |
| **MiMo Code** | 小米 AI 编程助手 | npm 全局安装（`@mimo-ai/cli`） |
| **ChatGPT/Codex 桌面版** | OpenAI 官方 Linux 桌面应用 | 官方 rpm/deb/安装脚本 |
| **CC Switch** | AI CLI 配置切换器（桌面版） | GitHub release rpm/deb/AppImage |

### 用法

```bash
./install_devtools.sh             # 默认进入 TUI，不预选；非交互须指定组件
./install_devtools.sh --all       # 显式安装全部组件
./install_devtools.sh --node      # 只装 Node 工具链 (nvm + LTS)
./install_devtools.sh --python    # 只装 pyenv + Python 编译依赖
./install_devtools.sh --ai        # 只装 AI CLI (claude-code + codex)
./install_devtools.sh --zed       # 只装 Zed 编辑器 + JetBrains Mono
./install_devtools.sh --ghostty   # 安装/修复 Ghostty、terminfo 和桌面终端入口
./install_devtools.sh --vscode    # 只装 VS Code 编辑器
./install_devtools.sh --mimo      # 只装 MiMo Code (小米 AI 编程助手)
./install_devtools.sh --chatgpt   # 只装 ChatGPT / Codex 桌面版
./install_devtools.sh --ccswitch  # 只装 CC Switch (AI CLI 配置切换器)
./install_devtools.sh --tui       # 交互式勾选界面 (可多选组件)
./install_devtools.sh --list      # 列出可安装组件及当前安装状态
./install_devtools.sh --help      # 查看完整用法与依赖说明
```

### TUI 交互式选择 (`--tui`)

运行 `./install_devtools.sh --tui` 打开终端交互界面，用键盘勾选要安装的组件：

- **↑/↓** 移动光标，**空格** 勾选/取消
- **a** 全选未安装，**n** 全不选，**i** 仅选未安装
- **回车** 开始安装，**q** 退出
- 所有组件默认不勾选；已安装的组件自动检测并显示 `[✓装]`，自动跳过

```bash
./install_devtools.sh --tui
./install_devtools.sh --list      # 列出可安装组件及当前安装状态
```

### 环境变量

- `NODE_LTS` - 指定 Node 版本（默认最新 LTS）
- `PROXY_URL` - 代理地址，如 `http://192.168.50.182:7890`（外网下载慢时使用）

### 注意事项

- 所有组件**幂等**：已安装的会自动跳过，可安全重复执行
- `--python` 只配置 pyenv 和编译依赖，Python 版本及 pipx 由用户自行安装
- 已存在的 `~/.config/zed/settings.json` 不会被覆盖（只在缺失时写入默认字体配置）
- AI CLI（Claude Code/Codex）安装后需各自登录/配置 API key 才能使用
- Zed 依赖 Vulkan，脚本按发行版自动安装对应驱动（pacman 下为 `vulkan-radeon`+`vulkan-intel`）
- Ghostty 安装后会检查用户和系统的 `xterm-ghostty` terminfo；AppImage 缺失主机端描述时，从 AppImage 中提取并用 `tic` 编译。除 `~/.terminfo` 外，系统条目缺失时还会通过 `sudo` 安装到 `/usr/share/terminfo`，避免普通用户和 `sudo minicom` 报 `No termcap entry for xterm-ghostty`。`infocmp`/`tic` 由 ncurses 工具包提供（apt: `ncurses-bin`，pacman/dnf: `ncurses`，zypper: `ncurses-utils`）
- Ghostty 桌面入口使用 `~/.local/bin/joe-ghostty`，将调用目录作为 `--working-directory` 显式传入，避免单实例复用时打开错误目录；Cinnamon/Nemo 的默认终端也会指向此入口
- Ghostty 在 Budgie/labwc 桌面下依赖 `xdg-terminal-exec`，发行版包不可用时尝试上游脚本
- 安装完成后新开终端生效（或 `source ~/.zshrc`）

### 修复已有 Ghostty

```bash
./repair_ghostty.sh                  # 修复已有安装；系统 terminfo 缺失时提示 sudo 密码
infocmp -x xterm-ghostty             # 验证当前用户的终端描述
sudo infocmp -x xterm-ghostty        # 验证 sudo 下的终端描述
sudo minicom -s                     # 验证 sudo 下的 minicom 配置界面
```

| 选项 | 行为 |
|---|---|
| 不带选项 | 修复用户/系统 terminfo 与桌面入口，必要时调用 `sudo` |
| `--user-only` | 只修复当前用户，不调用 `sudo`；无法补齐 `sudo minicom` 所需的系统条目 |
| `--help` | 显示用法 |

请以普通用户运行修复脚本，让它仅对系统条目的写入调用 `sudo`；不要用 `sudo` 运行整个脚本。修复不安装软件包，保留 Ghostty 的字体、主题和快捷键配置，为被修改的启动器、桌面文件、终端首选列表及 Cinnamon 设置创建 `*.bak.<timestamp>` 备份（保留最近 5 份）。桌面文件优先读取用户目录，再读取系统目录；终端首选列表保留其他终端作为回退。重复运行时内容无变化的文件保持不动。`doctor.sh` 分别检查用户和系统 terminfo，避免把只对当前用户可用的安装报告为全部正常。


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
