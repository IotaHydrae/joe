# Joe

> **中文** | [English](README.en.md)

自动化配置开发环境的工具集：终端美化（zsh + Oh My Zsh）、开发工具安装、AI 编程助手集成。

## 快速开始

> **版本 2.0 新特性** 🎉  
> - 更清晰的命令结构：`tools install <组件>`  
> - 自动依赖处理：不再需要手动记顺序  
> - 改进的 TUI：显示状态、版本和依赖  
> - 向后兼容：旧命令仍然工作  
> - 详见 [迁移指南](docs/MIGRATION.md)

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
- **Ghostty 配置**：包含 `term = xterm-256color` 修复常见问题
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
- **AI CLI**：Claude Code、Codex（`--ai` 只装这两个）、Gemini CLI、OpenCode、GitHub Copilot CLI、Grok Build
- **编辑器**：Zed、VS Code
- **终端**：Ghostty
- **其他**：MiMo Code、ChatGPT、CC Switch

```bash
# ===== 新版命令（推荐）=====
./install.sh tools                     # TUI 交互选择
./install.sh tools list                # 列出所有工具及状态
./install.sh tools install node        # 装 Node.js
./install.sh tools install claude      # 装 Claude Code（自动提示依赖）
./install.sh tools install --ai        # 装 AI 工具组（Claude + Codex）
./install.sh tools install claude codex gemini  # 一次装多个

# ===== 旧命令（仍然可用）=====
./install.sh devtools                  # = tools
./install.sh devtools --list           # = tools list
./install.sh devtools --node           # = tools install node
./install.sh devtools --ai             # = tools install --ai
```

**新特性**：
- 自动依赖检测和提示（不用手动记住顺序）
- 位置参数支持（`install claude codex` 更简洁）
- 改进的状态显示（显示版本、依赖关系）

### 3. MCP 服务器（MCP）
为 AI 编程助手安装 Model Context Protocol 服务器：

- **filesystem** / **git**：文件和代码管理
- **memory**：对话记忆
- **context7**：实时文档查询
- **代码智能**：codebase-memory-mcp、codegraph、serena（三选一）

已安装的 Gemini CLI、OpenCode、Grok Build、Zed 和 VS Code 会写入同一套 MCP。Copilot CLI 用 `copilot mcp add` 自行添加。`filesystem` 必须用 `FILESYSTEM_DIRS` 指定可访问目录。重复运行 `./install.sh mcp <id>` 会在命令变化时更新配置。

```bash
# ===== 新版命令（推荐）=====
./install.sh mcp                       # TUI 交互选择
./install.sh mcp list                  # 列出所有 MCP 及状态
./install.sh mcp install memory git    # 装指定服务
./install.sh mcp update filesystem     # 重跑安装器刷新该服务配置

# ===== 旧命令（仍然可用）=====
./install.sh mcp --list                # = mcp list
./install.sh mcp memory git            # 仍然工作
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
./install.sh skills list           # 列出技能及安装状态
./install.sh skills categories     # 列出分类及技能数量
./install.sh skills install gdb    # 只装 GDB 技能
./install.sh skills gdb            # 旧写法, 同样有效
./install.sh skills --category kernel-dev --tui  # 直接打开内核驱动分类
```

技能菜单分为「原有/本地技能（8 个）」和「low-level-dev-skills（142 个、25 个分类）」。后者先选分类，再勾选该分类的技能；默认不勾选任何项。编号进入，`b`/`q` 返回上一级；安装完成或退出勾选列表后返回当前菜单，可继续选择其他分类。指定 `--category` 则直接打开过滤后的列表，完成后退出安装器。非交互安装须指定技能名或显式使用 `--all`。

技能只在 `~/.agents/skills` 保留一份实体副本。Claude Code、Codex、Gemini、OpenCode、Grok Build、MiMo 和 Copilot 的技能目录使用指向它的符号链接。

## 常用命令

```bash
./install.sh                   # 主菜单
./install.sh tools list        # 列出工具
./install.sh mcp list          # 列出 MCP 服务
./install.sh doctor            # 环境检查
./install.sh --help            # 帮助信息
```

## 故障排除

遇到问题？查看：
- [故障排除指南](docs/TROUBLESHOOTING.md) - 常见问题和解决方案
- [Ghostty 终端修复](docs/GHOSTTY_FIX.md) - Ghostty 按键问题修复
- [迁移指南](docs/MIGRATION.md) - 1.x → 2.0 迁移

**快速修复 Ghostty**：
```bash
bash scripts/fix_ghostty_term.sh  # 修复 TERM=dumb 问题
```

## 维护命令

```bash
# 一键全装（新机器推荐, 会先确认）
./install.sh install-all

# 环境检查
./install.sh doctor                  # 检查安装状态
./install.sh doctor --quiet          # 只显示问题

# 更新
./install.sh update                  # 更新已安装组件

# 配置同步
./install.sh config list             # 查看配置映射
./install.sh config export           # 导出本机配置到仓库
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
--claude               # 只装 Claude Code
--codex                # 只装 Codex CLI
--ai                   # 同时装 Claude Code 和 Codex
--gemini               # 只装 Gemini CLI
--opencode             # 只装 OpenCode
--copilot              # 只装 GitHub Copilot CLI
--grok                 # 只装 Grok Build
--zed                  # 只装 Zed 编辑器
--vscode               # 只装 VS Code
--ghostty              # 只装 Ghostty 终端
--brave                # 只装 Brave 浏览器
--mimo                 # 只装 MiMo Code
--chatgpt              # 只装 ChatGPT Desktop
--ccswitch             # 只装 CC Switch
```

### MCP 选项
```bash
--tui                  # 强制进入 TUI 选择界面
--list                 # 列出所有 MCP 服务器
filesystem git         # 安装指定的 MCP（支持多个）
list / install / update  # 新版动作写法, 与上面的旧选项等价
```

### Skills 选项

| 参数 | 用途 |
|---|---|
| `--tui` | 技能组 / 分类子菜单；带 `--category` 时直接进入过滤后的勾选列表 |
| `--list` | 列出技能及安装状态 |
| `--categories` | 列出分类及技能数量 |
| `--category <name>` | 按分类过滤，可重复取并集；支持 `--list`、`--tui`、`--all` 和技能名 |
| `--all` | 显式安装全部技能；带分类过滤时仅安装所选分类 |
| `list` / `categories` / `install <技能>` | 新版动作写法，与 `--list` / `--categories` / 位置技能名等价 |

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
├── install.sh              # 主入口，命令路由与菜单
├── scripts/
│   ├── commands/           # tools/mcp/skills 动作转换层
│   ├── lib/                # 发行版 / GitHub / Node / 依赖解析库
│   ├── ui/                 # TUI 组件
│   ├── install_shell.sh    # Shell 环境安装
│   ├── install_devtools.sh # 开发工具安装
│   ├── install_mcp_servers.sh  # MCP 安装
│   ├── install_skills.sh   # 技能安装
│   ├── doctor.sh           # 环境检查
│   ├── update-all.sh       # 更新工具
│   └── sync-configs.sh     # 配置同步
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
