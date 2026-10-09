# Joe

> **中文** | [English](README.en.md)

自动化配置开发环境的工具集：终端美化（zsh + Oh My Zsh）、开发工具安装、AI 编程助手集成。

## 快速开始

### 一行安装
```bash
curl -fsSL https://raw.githubusercontent.com/IotaHydrae/joe/main/install.sh | bash
```

会克隆到 `~/.joe` 并打开菜单，选择需要的组件安装。

### 本地安装
```bash
git clone https://github.com/IotaHydrae/joe.git
cd joe
./install.sh
```

## 主要功能

### 1. 终端美化（Shell）
- **zsh** + **Oh My Zsh** 自动安装配置
- **powerlevel10k** 主题（优雅的命令行提示符）
- **常用插件**：自动补全、语法高亮、fzf 模糊搜索等
- **自动备份**：修改前备份原配置，保留最近 5 个

```bash
./install.sh shell              # 完整安装
./install.sh shell --dry-run    # 预览操作
./install.sh shell --no-fonts   # 跳过字体
```

### 2. 开发工具（Devtools）
跨发行版安装开发工具（支持 apt/pacman/dnf/zypper）：

- **Node.js**：nvm + LTS 版本
- **Python**：pyenv（不预装 Python，你自己选版本）
- **AI CLI**：Claude Code、Codex
- **编辑器**：Zed、VS Code
- **终端**：Ghostty
- **其他**：MiMo Code、ChatGPT、CC Switch

```bash
./install.sh devtools              # TUI 交互选择
./install.sh devtools --list       # 列出所有组件
./install.sh devtools --node       # 只装 Node.js
./install.sh devtools --python     # 只装 pyenv
./install.sh devtools --ai         # 只装 AI CLI
```

### 3. MCP 服务器（MCP）
为 AI 编程助手安装 Model Context Protocol 服务器：

- **filesystem** / **git**：文件和代码管理
- **memory**：对话记忆
- **context7**：实时文档查询
- **代码智能**：codebase-memory-mcp、codegraph、serena（三选一）

```bash
./install.sh mcp                   # TUI 交互选择
./install.sh mcp --list            # 列出所有 MCP
./install.sh mcp filesystem git    # 只装指定的
```

**使用提示**：首次使用代码智能 MCP 时，在项目里说"索引这个项目"。

### 4. 代理技能（Skills）
为 AI 助手添加专业技能模板：

- **代码探索**：跨项目代码导航
- **开发质量**：代码审查规范
- **仓库探索**：快速理解新项目
- **测试**：测试策略和实现
- **嵌入式**：启动优化等专项技能
- **low-level-dev-skills**：142 个底层开发技能，按 25 个分类选择

```bash
./install.sh skills                # 技能组 → 分类 → 按需勾选
./install.sh skills gdb            # 只装 GDB 技能
./install.sh skills --category kernel-dev --tui  # 直接打开内核驱动分类
```

技能菜单分为「原有/本地技能（8 个）」和「low-level-dev-skills（142 个、25 个分类）」。后者先选分类，再勾选该分类的技能；默认不勾选任何项。编号进入，`b`/`q` 返回上一级；安装完成或退出勾选列表后返回当前菜单，可继续选择其他分类。指定 `--category` 则直接打开过滤后的列表，完成后退出安装器。非交互安装须指定技能名或显式使用 `--all`。

## 常用命令

```bash
# 一键全装（新机器推荐）
./install.sh shell devtools mcp skills

# 环境检查
./doctor.sh                        # 检查安装状态
./doctor.sh --quiet                # 只显示问题

# 更新
./update-all.sh                    # 更新所有组件

# 配置同步
./sync-configs.sh                  # 同步配置文件
```

## 选项说明

### Shell 选项
```bash
--dry-run              # 模拟运行，不实际修改
--no-fonts             # 跳过字体安装
--no-config            # 跳过 .config 复制
--no-p10k              # 跳过 powerlevel10k
--no-fastfetch         # 跳过 fastfetch
--clean-backups        # 清理旧备份（保留最近 5 个）
-u, --update           # 更新已安装组件
```

### Devtools 选项
```bash
--tui                  # 强制进入 TUI 选择界面
--list                 # 列出所有组件及状态
--node                 # 只装 Node.js 工具链
--python               # 只装 Python 工具链
--ai                   # 只装 AI CLI
--zed                  # 只装 Zed 编辑器
--vscode               # 只装 VS Code
```

### MCP 选项
```bash
--tui                  # 强制进入 TUI 选择界面
--list                 # 列出所有 MCP 服务器
filesystem git         # 安装指定的 MCP（支持多个）
```

### Skills 选项

| 参数 | 用途 |
|---|---|
| `--tui` | 技能组 / 分类子菜单；带 `--category` 时直接进入过滤后的勾选列表 |
| `--list` | 列出技能及安装状态 |
| `--categories` | 列出分类及技能数量 |
| `--category <name>` | 按分类过滤，可重复取并集；支持 `--list`、`--tui`、`--all` 和技能名 |
| `--all` | 显式安装全部技能；带分类过滤时仅安装所选分类 |

分类与数量由 `skills/categories.tsv` 和技能目录生成；原有及自定义技能归入 `local`。完整清单见 [low-level-dev-skills](skills/low-level-dev-skills.md)。

## 系统支持

已验证的发行版：

| 发行版 | 包管理器 | 状态 |
|--------|---------|------|
| Ubuntu 24.04 / 22.04 | apt | ✅ |
| Linux Mint 22.3 | apt | ✅ |
| Arch Linux / CachyOS | pacman | ✅ |
| Fedora | dnf | ✅ |
| openSUSE | zypper | ✅ |

## 常见问题

### pyenv 安装后没有 Python？
这是正常的，你需要手动选择版本：
```bash
pyenv install --list      # 查看可用版本
pyenv install 3.12.0      # 安装指定版本
pyenv global 3.12.0       # 设为全局版本
```

### MCP 服务器不工作？
1. 检查连接状态：`claude mcp list`（或 `codex mcp list`）
2. 代码智能 MCP 需要先索引：在项目里对 AI 说"索引这个项目"
3. 查看详细日志：`~/.claude/mcp.log`

### 如何让 AI 助手使用 MCP？
最有效的方法是在项目根目录放规则文件：
```bash
cp ~/.joe/templates/AGENTS.md /your/project/
cp ~/.joe/templates/CLAUDE.md /your/project/
```

### 代码智能 MCP 怎么选？
- **大仓库（>5000 文件）**：`codebase-memory-mcp`（查询延迟恒定）
- **需要语义搜索**：`codegraph`
- **需要精确重构**：`serena`（依赖 LSP）

详见 [`skills/code-exploration/SKILL.md`](skills/code-exploration/SKILL.md)

## 项目结构

```
joe/
├── install.sh              # 主入口，统一菜单
├── doctor.sh               # 环境检查
├── update-all.sh           # 更新工具
├── sync-configs.sh         # 配置同步
├── scripts/
│   ├── install_shell.sh    # Shell 环境安装
│   ├── install_devtools.sh # 开发工具安装
│   ├── install_mcp_servers.sh  # MCP 安装
│   └── install_skills.sh   # 技能安装
├── skills/                 # 代理技能模板
├── templates/              # 项目规则文件模板
├── .config/                # 配置文件（Ghostty 等）
└── fonts/                  # 字体文件
```

## 高级用法

### 环境变量
```bash
JOE_INSTALL_DIR=~/my-joe    # 自定义安装目录（默认 ~/.joe）
PROXY_URL=http://proxy:7890 # 使用代理
```

### 离线安装
```bash
# 在有网络的机器上
git clone --depth 1 https://github.com/IotaHydrae/joe.git
cd joe
./install.sh devtools --list  # 确认需要的组件

# 打包
tar czf joe.tar.gz joe/

# 在离线机器上
tar xzf joe.tar.gz
cd joe
./install.sh shell  # 基础功能可离线
```

### 贡献
欢迎提交 Issue 和 Pull Request！

### 许可证
MIT License

---

**提示**：首次运行建议用 `--dry-run` 预览，确认无误后再实际安装。
