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

主菜单第 1 项和 `shell` 命令使用同一套优化后的 zsh 配置：新配置只启用 `git sudo extract z history dirhistory` 六个 OMZ 插件；主题使用已安装的 powerlevel10k 或 robbyrussell。自动建议异步运行，语法高亮最后加载，fzf 直接加载已有的补全与快捷键脚本。Node/Python 通过固定 PATH 可用，首次调用 `nvm` / `pyenv` 时再初始化版本管理器。OMZ 自动更新检查关闭，可用 `./install.sh shell --update` 显式更新。

已有的别名、自定义 PATH、代理设置和插件选择会保留；个人配置集中在 `.zshrc` 的用户区块，也可放入 `~/.zshrc.local`。`--configure-only` 可离线应用配置，修改前备份为 `.zshrc.bak.<timestamp>`，保留最近 5 份；内容相同时不改写文件。

```bash
./install.sh shell                              # 完整安装并应用优化配置
./install.sh shell --dry-run                    # 预览操作
./install.sh shell --configure-only             # 仅离线更新 zsh 配置
./install.sh shell --configure-only --dry-run   # 预览配置迁移
./install.sh shell --no-fonts                   # 跳过字体
```

### 字体安装（Fonts）

主菜单第 6 项「字体安装」或 `./install.sh fonts` 打开编号子菜单：选择 Fixedsys Excelsior（FSEX302）或 JetBrains Mono，查看已安装状态，也可全部安装，`b` 返回主菜单。安装完成后留在当前子菜单。

字体从仓库安装到 `~/.local/share/fonts`，可离线使用，无需 sudo。JetBrains Mono 2.304 包含常规、粗体、斜体和粗斜体，附带 [SIL OFL 许可证](fonts/jetbrains-mono/OFL.txt)。`shell` 默认安装 Fixedsys Excelsior；JetBrains Mono 可从字体菜单单独安装。

```bash
./install.sh fonts list                           # 查看字体及安装状态
./install.sh fonts install fsex302                # 安装 Fixedsys Excelsior
./install.sh fonts install jetbrains-mono         # 安装 JetBrains Mono
./install.sh fonts install --all                  # 安装全部字体
./install.sh fonts install --dry-run --all        # 预览安装
```

### 2. 开发工具（Devtools）
跨发行版安装开发工具（支持 apt/pacman/dnf/zypper）：

主菜单第 3 项「开发工具」与第 2 项「日常软件」使用相同的编号列表：显示已安装状态，输入编号安装单项，也可全部安装，`b` 返回主菜单。安装完成后留在当前子菜单。

- **Node.js**：nvm + LTS 版本
- **Python**：pyenv（不预装 Python，你自己选版本）
- **AI CLI**：Claude Code、Codex（`--ai` 只装这两个）、Gemini CLI、OpenCode、GitHub Copilot CLI、Grok Build
- **编辑器**：Zed、VS Code
- **终端**：Ghostty
- **游戏开发**：Godot 游戏引擎
- **其他**：MiMo Code、CC Switch
- **日常软件**：Brave 浏览器、ChatGPT Desktop、微信 Linux 原生版、Linux QQ、Rime 雾凇拼音输入法。主菜单第 2 项，或 `./install.sh tools install brave` / `chatgpt` / `wechat` / `qq` / `rime`。不包含在 `devtools --all`、`tools install --all` 和 `quick-start --yes` 中

```bash
# ===== 新版命令（推荐）=====
./install.sh tools                     # TUI 交互选择
./install.sh tools list                # 列出所有工具及状态
./install.sh tools install node        # 装 Node.js
./install.sh tools install claude      # 装 Claude Code（自动提示依赖）
./install.sh tools install --ai        # 装 AI 工具组（Claude + Codex）
./install.sh tools install claude codex gemini  # 一次装多个
./install.sh tools update              # 统一更新所有工具（官方自更新机制）
./install.sh tools update claude node  # 只更新指定组件
./install.sh tools update --dry-run    # 预览将执行的更新

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

主菜单第 4 项「MCP 服务器」同样使用编号列表，显示已配置状态，支持单项或全部安装，`b` 返回主菜单。代码智能服务会标记「三选一」，安装前会检查 Node/npx。

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

`./install.sh mcp` 的 TUI 按「文件与仓库 / 记忆与文档 / 代码智能（三选一）」分组，
显示每个服务是否已在已安装的 AI CLI 里配置，并在状态栏提示 Node/npx 依赖；
缺 npx 时安装前会直接告诉你先运行 `./install.sh tools install node`。

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
./install.sh fonts list        # 列出字体及状态
./install.sh tools list        # 列出工具
./install.sh mcp list          # 列出 MCP 服务
./install.sh status            # 一屏汇总 工具/MCP/技能 安装数
./install.sh status --short    # 单行汇总, 便于脚本使用
./install.sh doctor            # 环境检查
./install.sh --help            # 帮助信息
```

## 故障排除

遇到问题？查看：
- [故障排除指南](docs/TROUBLESHOOTING.md) - 常见问题和解决方案
- [Ghostty 终端修复](docs/GHOSTTY_FIX.md) - terminfo、桌面入口和 Fixedsys 字体优先级修复
- [迁移指南](docs/MIGRATION.md) - 1.x → 2.0 迁移

**快速修复 Ghostty**：
```bash
./install.sh repair-ghostty              # 修复 terminfo、桌面入口和 Fixedsys 字体优先级
./install.sh repair-ghostty --user-only  # 仅修当前用户，不写系统 terminfo
```

修复命令以及 `./install.sh tools install ghostty` 会部署用户级字体规则 `${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/conf.d/99-fixedsys-explicit.conf`；`shell` 复制配置时也会合并这条规则，保留其他用户字体规则，`--no-config` 可跳过。仅在程序明确请求 `Fixedsys Excelsior` 时，将字体顺序设为 Fixedsys → Noto Sans Mono CJK SC → Noto Color Emoji，并移除这类请求中的通用 `monospace` 标记，避免中文语言规则抢占 Fixedsys；其他字体和普通 `monospace` 请求不受影响。

规则变化时会备份旧文件、保留最近 5 份，并在有 `fc-cache` 时刷新字体缓存；不会安装缺失的回退字体。完成后重启 Ghostty，并在与桌面一致的 `zh_CN.UTF-8` 环境下验证英文、中文和表情，详见[字体修复说明](docs/GHOSTTY_FIX.md#fixedsys-字体优先级修复)。

修复还会更新 `~/.local/bin/joe-ghostty` 启动器：每次创建独立进程，使新窗口加载当前安装的输入法模块；X11 有 `wmctrl` 时只激活本次新增的 Ghostty 窗口，配合 `xprop` 确认焦点并在请求未被接受时短暂重试；Wayland 使用原生焦点行为。已有 Cinnamon 自定义快捷键若直接执行 `ghostty`，会备份后迁移到这个启动器，并刷新 Cinnamon 内存中的快捷键命令，立即生效；其他自定义命令保留，不修改全局焦点策略。

## 维护命令

```bash
# 一键全装（新机器推荐, 会先确认）
./install.sh install-all
./install.sh quick-start            # 引导式部署 shell/工具/MCP/技能/体检
./install.sh quick-start --yes      # 非交互全部安装 (脚本/CI)
./install.sh quick-start --skip shell   # 跳过某个阶段

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
--configure-only       # 仅离线更新 zsh 配置，不安装软件、下载、切换默认 shell 或复制字体/.config
--no-fonts             # 跳过字体安装
--no-config            # 跳过 .config 复制
--no-p10k              # 跳过 powerlevel10k
--no-fastfetch         # 跳过 fastfetch
--no-default-plugins   # 新配置仅启用 git；保留已有插件选择
--clean-backups        # 清理旧备份（保留最近 5 个）
-u, --update           # 更新已安装组件
```

### Fonts 选项

| 参数 | 用途 |
|---|---|
| `list` / `status` | 列出字体及安装状态，只读 |
| `install fsex302` | 安装 Fixedsys Excelsior（FSEX302） |
| `install jetbrains-mono` | 安装 JetBrains Mono；支持同时指定多个字体 id |
| `install --all` | 显式安装全部字体 |
| `install --dry-run <id...>` / `install --dry-run --all` | 预览安装，不修改文件或字体缓存 |
| `--help` | 查看字体命令帮助 |

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
--godot                # 只装 Godot 游戏引擎
--wechat               # 只装微信 Linux 原生版
--qq                   # 只装 Linux QQ
--rime                 # 安装/修复 Rime 雾凇拼音, 保留个人词库
```

重复运行 `./install.sh tools install rime`（或主菜单第 2 项选择 Rime）会修复已有安装：补齐 Fcitx 5 的 GTK/Qt 前端和 Rime Lua 插件，重新编译雾凇，合并输入法列表与左 Alt+Shift 快捷键，并通过 `im-config`（可用时）选择 Fcitx 5。保留个人词库、其他输入法和无关环境变量；变更前备份配置，保留最近 5 份。

部署失败会显示错误，已有但不完整的词库目录会保留并提示处理。桌面会话中的旧 Fcitx 4 会优雅退出，Fcitx 5 会重启；脚本不会自动卸载旧软件包。已打开的 Ghostty 等应用需要关闭后重新打开，以加载新装的输入法模块。`doctor` 会检查雾凇编译产物与输入法列表，并提示仍指向 Fcitx 4 的登录配置和残留旧后台。

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

需要 bash ≥ 4.4（空数组在 `set -u` 下的展开行为）以及 GNU coreutils/findutils。

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
│   ├── commands/           # tools/mcp/skills/fonts 动作转换层
│   ├── lib/                # 发行版 / Node / zsh 迁移 / 依赖与字体清单
│   ├── ui/                 # TUI 组件
│   ├── install_shell.sh    # Shell 环境安装
│   ├── install_fonts.sh    # 用户字体安装
│   ├── install_devtools.sh # 开发工具安装
│   ├── install_mcp_servers.sh  # MCP 安装
│   ├── install_skills.sh   # 技能安装
│   ├── doctor.sh           # 环境检查
│   ├── update-all.sh       # 更新工具
│   └── sync-configs.sh     # 配置同步
├── skills/                 # 代理技能模板
├── templates/              # 项目规则与 zsh 配置模板
├── .config/                # 配置文件（Ghostty 等）
└── fonts/                  # FSEX302 与 JetBrains Mono 字体及许可证
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
